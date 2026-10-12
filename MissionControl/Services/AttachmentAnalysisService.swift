import PDFKit
import UIKit
import UniformTypeIdentifiers
import Vision

/// Device-local preparation for future assistant uploads. Nothing is persisted
/// or transmitted yet; the extracted payload is shown in the assistant message.
enum AttachmentAnalysisService {
    static func analyze(image: UIImage, source: String) throws -> String {
        guard let image = image.cgImage else { throw AnalysisError.unreadableImage }
        return format(source: source, content: try recognizeText(in: image))
    }

    static func analyze(data: Data, type: UTType, source: String) throws -> String {
        if type.conforms(to: .pdf) {
            guard let document = PDFDocument(data: data) else { throw AnalysisError.unreadablePDF }
            return try analyze(document: document, source: source)
        }
        guard type.conforms(to: .image), let image = UIImage(data: data) else {
            throw AnalysisError.unsupportedAttachment
        }
        return try analyze(image: image, source: source)
    }

    private static func analyze(document: PDFDocument, source: String) throws -> String {
        guard document.pageCount > 0 else { throw AnalysisError.unreadablePDF }
        let pageLimit = min(document.pageCount, 8)
        let pages = try (0..<pageLimit).compactMap { index -> String? in
            guard let page = document.page(at: index) else { return nil }
            let image = page.thumbnail(of: CGSize(width: 1_800, height: 2_400), for: .mediaBox)
            let text = try recognizeText(in: image.cgImage)
            return text.isEmpty ? nil : "Page \(index + 1)\n\(text)"
        }
        return format(source: source, content: pages.joined(separator: "\n\n"))
    }

    private static func recognizeText(in image: CGImage?) throws -> String {
        guard let image else { throw AnalysisError.unreadableImage }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private static func format(source: String, content: String) -> String {
        let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty
            ? "\(source)\n\nNo readable text was found. The attachment is ready for the future assistant backend."
            : "\(source)\n\n\(clean)"
    }

    enum AnalysisError: LocalizedError {
        case unreadableImage, unreadablePDF, unsupportedAttachment

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "That image couldn’t be read."
            case .unreadablePDF: "That PDF couldn’t be read."
            case .unsupportedAttachment: "Choose an image or PDF."
            }
        }
    }
}
