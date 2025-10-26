import SwiftUI
import VisionKit
import UIKit

struct ScannedDocument {
    let data: Data
    let pageCount: Int
    let suggestedTitle: String
}

struct DocumentScannerView: UIViewControllerRepresentable {
    var onCompletion: (Result<ScannedDocument, Error>) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onCompletion: (Result<ScannedDocument, Error>) -> Void
        
        init(onCompletion: @escaping (Result<ScannedDocument, Error>) -> Void) {
            self.onCompletion = onCompletion
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.onCompletion(.failure(error))
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            do {
                let rendered = try renderPDF(from: scan)
                controller.dismiss(animated: true) {
                    self.onCompletion(.success(rendered))
                }
            } catch {
                controller.dismiss(animated: true) {
                    self.onCompletion(.failure(error))
                }
            }
        }
        
        private func renderPDF(from scan: VNDocumentCameraScan) throws -> ScannedDocument {
            guard scan.pageCount > 0 else {
                throw DocumentStore.StoreError.invalidScan
            }
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
            let data = renderer.pdfData { context in
                for index in 0..<scan.pageCount {
                    context.beginPage()
                    let image = scan.imageOfPage(at: index)
                    let aspect = image.size.width / image.size.height
                    var drawRect = context.pdfContextBounds
                    if aspect > drawRect.width / drawRect.height {
                        let height = drawRect.width / aspect
                        drawRect.origin.y += (drawRect.height - height) / 2
                        drawRect.size.height = height
                    } else {
                        let width = drawRect.height * aspect
                        drawRect.origin.x += (drawRect.width - width) / 2
                        drawRect.size.width = width
                    }
                    image.draw(in: drawRect)
                }
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let suggestedTitle = "Scanned \(formatter.string(from: Date()))"
            return ScannedDocument(data: data, pageCount: scan.pageCount, suggestedTitle: suggestedTitle)
        }
    }
}
