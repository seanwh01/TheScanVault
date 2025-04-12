import SwiftUI
import UIKit

// ZoomableScrollView: A SwiftUI wrapper around UIScrollView that supports zooming
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // Set up the UIScrollView with fixed boundaries
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = maxScale
        scrollView.minimumZoomScale = minScale
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = true
        scrollView.contentInsetAdjustmentBehavior = .never
        
        // Create a UIHostingController to hold our SwiftUI content
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        
        scrollView.addSubview(hostedView)
        
        // Fixed size constraints that won't change during zoom
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // Fixed width constraint
            hostedView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update the hosting controller's SwiftUI content
        context.coordinator.hostingController.rootView = content
        
        // Calculate content size based on the content, not the frame
        let contentSize = context.coordinator.hostingController.view.sizeThatFits(uiView.frame.size)
        
        // Only set content size once or when it needs to change
        if uiView.contentSize.width != contentSize.width || uiView.contentSize.height != contentSize.height {
            uiView.contentSize = contentSize
        }
        
        // Start with unzoomed view
        if uiView.zoomScale <= minScale && !context.coordinator.initialZoomSet {
            uiView.zoomScale = minScale
            context.coordinator.initialZoomSet = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: content))
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        var initialZoomSet = false
        
        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Center the zoomed content within the fixed frame
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width * scrollView.zoomScale) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height * scrollView.zoomScale) * 0.5, 0)
            
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
        }
    }
} 