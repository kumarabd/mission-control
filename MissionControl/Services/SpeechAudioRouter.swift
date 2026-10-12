import AVFAudio
import Foundation
import Speech

/// Bridges the real-time audio callback to SpeechAnalyzer without touching
/// main-actor coordinator state. A lock owns format conversion, stream handoff,
/// energy samples and a bounded three-second pre-roll during turn finalization.
/// Audio remains in memory and never leaves the device.
final class SpeechAnalyzerAudioRouter: @unchecked Sendable {
    struct Diagnostics {
        let capturedBuffers: Int
        let yieldedBuffers: Int
        let conversionFailures: Int
    }

    private let lock = NSLock()
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?
    private var preRoll = [AVAudioPCMBuffer]()
    private var bufferedDuration: Double = 0
    private var energyTimes = [TimeInterval]()
    private var lastEnergySample: TimeInterval = 0
    private var capturedBuffers = 0
    private var yieldedBuffers = 0
    private var conversionFailures = 0

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        capturedBuffers += 1

        if let continuation, let analyzerFormat {
            if let input = analyzerInput(from: buffer, targetFormat: analyzerFormat) {
                continuation.yield(input)
                yieldedBuffers += 1
            } else {
                conversionFailures += 1
            }
        } else if let copy = copyPCM(buffer) {
            preRoll.append(copy)
            bufferedDuration += Double(copy.frameLength) / copy.format.sampleRate
            while bufferedDuration > 3, !preRoll.isEmpty {
                let oldest = preRoll.removeFirst()
                bufferedDuration -= Double(oldest.frameLength) / oldest.format.sampleRate
            }
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastEnergySample >= 0.03 else { return }
        lastEnergySample = now
        // RMS rejects isolated sample peaks. This remains endpoint evidence, not
        // a decision to cancel or pause assistant playback by itself.
        if let samples = buffer.floatChannelData?.pointee {
            var sum: Float = 0
            var count = 0
            for index in stride(from: 0, to: Int(buffer.frameLength), by: 8) {
                sum += samples[index] * samples[index]
                count += 1
            }
            if count > 0, sqrt(sum / Float(count)) >= 0.008 {
                energyTimes.append(now)
                if energyTimes.count > 32 { energyTimes.removeFirst() }
            }
        }
    }

    func install(
        _ continuation: AsyncStream<AnalyzerInput>.Continuation,
        analyzerFormat: AVAudioFormat
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation?.finish()
        self.continuation = continuation
        self.analyzerFormat = analyzerFormat
        converter = nil
        converterInputFormat = nil

        for buffer in preRoll {
            if let input = analyzerInput(from: buffer, targetFormat: analyzerFormat) {
                continuation.yield(input)
                yieldedBuffers += 1
            } else {
                conversionFailures += 1
            }
        }
        preRoll.removeAll()
        bufferedDuration = 0
    }

    /// Ends only the current analyzer input sequence. Audio arriving immediately
    /// afterward is retained as pre-roll for the next turn.
    func finish() {
        lock.lock()
        let current = continuation
        continuation = nil
        analyzerFormat = nil
        converter = nil
        converterInputFormat = nil
        lock.unlock()
        current?.finish()
    }

    func clear() {
        lock.lock()
        let current = continuation
        continuation = nil
        analyzerFormat = nil
        converter = nil
        converterInputFormat = nil
        preRoll.removeAll()
        bufferedDuration = 0
        energyTimes.removeAll()
        lastEnergySample = 0
        capturedBuffers = 0
        yieldedBuffers = 0
        conversionFailures = 0
        lock.unlock()
        current?.finish()
    }

    func takeEnergyTimes() -> [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        let result = energyTimes
        energyTimes.removeAll(keepingCapacity: true)
        return result
    }

    func diagnostics() -> Diagnostics {
        lock.lock()
        defer { lock.unlock() }
        return Diagnostics(
            capturedBuffers: capturedBuffers,
            yieldedBuffers: yieldedBuffers,
            conversionFailures: conversionFailures
        )
    }

    private func analyzerInput(
        from source: AVAudioPCMBuffer,
        targetFormat: AVAudioFormat
    ) -> AnalyzerInput? {
        if source.format == targetFormat {
            guard let copy = copyPCM(source) else { return nil }
            return AnalyzerInput(buffer: copy)
        }

        if converter == nil || converterInputFormat != source.format {
            converter = AVAudioConverter(from: source.format, to: targetFormat)
            // Live microphone input cannot provide the converter's requested
            // future priming frames. Latency mode avoids holding the first audio
            // buffers while waiting for samples that do not exist yet.
            converter?.primeMethod = .none
            converterInputFormat = source.format
        }
        guard let converter else { return nil }

        let ratio = targetFormat.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(source.frameLength) * ratio)) + 32
        guard let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: max(capacity, 1)
        ) else { return nil }

        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return source
        }
        guard conversionError == nil, status != .error, output.frameLength > 0 else { return nil }
        return AnalyzerInput(buffer: output)
    }

    private func copyPCM(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let target = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: source.frameLength
        ) else { return nil }
        target.frameLength = source.frameLength
        let from = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let to = UnsafeMutableAudioBufferListPointer(target.mutableAudioBufferList)
        for index in from.indices {
            guard let sourceData = from[index].mData,
                  let targetData = to[index].mData
            else { continue }
            memcpy(targetData, sourceData, Int(from[index].mDataByteSize))
        }
        return target
    }
}
