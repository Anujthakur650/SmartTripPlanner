import PDFKit
import QuickLook
import SwiftUI
import UIKit

struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemBackground
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil || pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let completion: UIActivityViewController.CompletionWithItemsHandler?
    
    init(activityItems: [Any], completion: UIActivityViewController.CompletionWithItemsHandler? = nil) {
        self.activityItems = activityItems
        self.completion = completion
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = completion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
enum ExternalDocumentOpener {
    static func open(url: URL) {
        guard let presenter = UIApplication.topMostViewController() else { return }
        let controller = UIDocumentInteractionController(url: url)
        DocumentInteractionDelegate.shared.attach(controller)
        controller.presentOptionsMenu(from: presenter.view.bounds, in: presenter.view, animated: true)
    }
}

final class DocumentInteractionDelegate: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = DocumentInteractionDelegate()
    private var controller: UIDocumentInteractionController?
    
    func attach(_ controller: UIDocumentInteractionController) {
        self.controller = controller
        controller.delegate = self
    }
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        UIApplication.topMostViewController() ?? UIViewController()
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        self.controller = nil
    }
    
    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        self.controller = nil
    }
}
