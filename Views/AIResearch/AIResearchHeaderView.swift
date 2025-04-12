import SwiftUI
import UIKit

// Place all components in the namespace
extension Views_AIResearch {
    // Header view for AI Research
    struct AIResearchHeaderView: View {
        var body: some View {
            VStack(spacing: 10) {
                // Replace static image with GIF animation, using same sizing as before
                GIFImageView(gifName: "ScanVaultAI_ScanAnimation")
                    .frame(width: 160)
                    .padding(.top, 20)
                
                Text("Find Documents for AI Research")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
            .padding(.bottom, 20)
        }
    }

    // GIF image view for displaying animated GIFs
    struct GIFImageView: UIViewRepresentable {
        let gifName: String
        
        func makeUIView(context: Context) -> UIImageView {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit // This ensures proper aspect ratio
            
            // Load the GIF
            if let path = Bundle.main.path(forResource: gifName, ofType: "gif"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let source = CGImageSourceCreateWithData(data as CFData, nil) {
                
                // Get frame count and duration
                let count = CGImageSourceGetCount(source)
                var images = [UIImage]()
                var totalDuration: TimeInterval = 0
                
                // Extract all frames and their durations
                for i in 0..<count {
                    if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                        images.append(UIImage(cgImage: image))
                        
                        // Get frame duration
                        if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                           let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                           let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                            totalDuration += delayTime
                        }
                    }
                }
                
                // Set the animation
                imageView.animationImages = images
                imageView.animationDuration = totalDuration
                imageView.animationRepeatCount = 0 // Infinite loop
                imageView.startAnimating()
            } else {
                // Fallback to static image if GIF loading fails
                imageView.image = UIImage(named: "ScanVaultLogoforAppTM")
            }
            
            return imageView
        }
        
        func updateUIView(_ uiView: UIImageView, context: Context) {
            // Nothing to update
        }
    }
} 