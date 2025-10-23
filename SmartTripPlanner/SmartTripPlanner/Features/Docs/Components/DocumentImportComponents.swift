import SwiftUI
import UniformTypeIdentifiers
import UIKit
import VisionKit

struct DocumentPickerView: UIViewControllerRepresentable {
    typealias Completion = (Result<URL, Error>) -> Void
    
    let onCompletion: Completion
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var contentTypes: [UTType] = [.pdf, .image]
        if let pkpass = UTType(filenameExtension: "pkpass") {
            contentTypes.append(pkpass)
        }
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCompletion: Completion
        
        init(onCompletion: @escaping Completion) {
            self.onCompletion = onCompletion
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion(.failure(DocumentImportError.cancelled))
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCompletion(.failure(DocumentImportError.noSelection))
                return
            }
            onCompletion(.success(url))
        }
    }
}

struct DocumentScannerResult {
    let images: [UIImage]
    let suggestedTitle: String
}

struct DocumentScannerView: UIViewControllerRepresentable {
    typealias Completion = (Result<DocumentScannerResult, Error>) -> Void
    
    let onCompletion: Completion
    let preferredTitle: String
    
    init(preferredTitle: String = "Scanned Document", onCompletion: @escaping Completion) {
        self.onCompletion = onCompletion
        self.preferredTitle = preferredTitle
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(preferredTitle: preferredTitle, onCompletion: onCompletion)
    }
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onCompletion: Completion
        private let preferredTitle: String
        
        init(preferredTitle: String, onCompletion: @escaping Completion) {
            self.preferredTitle = preferredTitle
            self.onCompletion = onCompletion
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            controller.dismiss(animated: true) {
                if images.isEmpty {
                    self.onCompletion(.failure(DocumentImportError.noScanPages))
                } else {
                    let result = DocumentScannerResult(images: images, suggestedTitle: self.preferredTitle)
                    self.onCompletion(.success(result))
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.onCompletion(.failure(DocumentImportError.cancelled))
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.onCompletion(.failure(error))
            }
        }
    }
}

enum DocumentImportError: LocalizedError, Equatable {
    case cancelled
    case noSelection
    case noScanPages
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The operation was cancelled."
        case .noSelection:
            return "No document was selected."
        case .noScanPages:
            return "No pages were captured during the scan."
        }
    }
}
