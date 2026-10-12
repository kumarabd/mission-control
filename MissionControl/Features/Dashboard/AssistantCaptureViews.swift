import SwiftUI
import UIKit
import VisionKit

/// VisionKit's live, on-device text and barcode scanner.
struct AssistantLiveScanner: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    LiveDataScanner { content in
                        onCapture(content)
                        dismiss()
                    }
                } else {
                    ContentUnavailableView("Scanner unavailable", systemImage: "viewfinder",
                                           description: Text("Live text and code scanning isn’t available on this device right now."))
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct LiveDataScanner: UIViewControllerRepresentable {
    let onCapture: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: [], textContentType: nil), .barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCapture: (String) -> Void
        init(onCapture: @escaping (String) -> Void) { self.onCapture = onCapture }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text): onCapture("Live text scan\n\n\(text.transcript)")
            case .barcode(let code): onCapture("Live code scan\n\n\(code.payloadStringValue ?? "Unreadable code")")
            @unknown default: break
            }
        }
    }
}

struct AssistantCameraCapture: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AssistantCameraCapture
        init(parent: AssistantCameraCapture) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isPresented = false }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.isPresented = false
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
        }
    }
}
