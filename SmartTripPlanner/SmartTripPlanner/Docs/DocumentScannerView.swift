import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    static var isSupported: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        VNDocumentCameraViewController.isSupported
        #endif
    }
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
            parent.completion(.success([]))
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.presentationMode.wrappedValue.dismiss()
            parent.completion(.failure(error))
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            parent.presentationMode.wrappedValue.dismiss()
            parent.completion(.success(images))
        }
    }
    
    @Environment(\.presentationMode) private var presentationMode
    let completion: (Result<[UIImage], Error>) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // no-op
    }
    
    static func dismantleUIViewController(_ uiViewController: VNDocumentCameraViewController, coordinator: Coordinator) {
        uiViewController.delegate = nil
    }
}
