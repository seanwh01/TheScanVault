import SwiftUI
import UIKit

extension Views_AIResearch {
    // Reusable checkbox view
    struct CheckboxView: View {
        let isChecked: Bool
        var partiallySelected: Bool = false
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .background(
                        isChecked ? 
                            RoundedRectangle(cornerRadius: 4).fill(Color.blue) : 
                            RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                    )
                
                if isChecked {
                    Image(systemName: "checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                        .foregroundColor(.white)
                } else if partiallySelected {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12 / 2)
                }
            }
        }
    }
}

// Haptic feedback style options
enum HapticStyle {
    case none, light, medium, heavy, soft, rigid
    
    func generateFeedback() {
        guard self != .none else { return }
        
        #if os(iOS)
        // Check if device supports haptics
        guard #available(iOS 13.0, *), UIDevice.hasHapticFeedback else { return }
        
        // Safe implementation that won't throw errors
        let generator: UIImpactFeedbackGenerator
        switch self {
        case .none: return
        case .light: generator = UIImpactFeedbackGenerator(style: .light)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy: generator = UIImpactFeedbackGenerator(style: .heavy)
        case .soft: generator = UIImpactFeedbackGenerator(style: .soft)
        case .rigid: generator = UIImpactFeedbackGenerator(style: .rigid)
        }
        
        generator.prepare()
        generator.impactOccurred()
        #elseif os(macOS)
        // macOS doesn't support haptic feedback in the same way
        // We could implement sound feedback here if desired
        #endif
    }
}

#if os(iOS)
// Extension to check if device supports haptic feedback
extension UIDevice {
    static var hasHapticFeedback: Bool {
        if #available(iOS 13.0, *) {
            return true // Most modern devices support haptics
        }
        
        // For older devices, we can do a more specific check
        // But since our generateFeedback is already guarded for iOS 13+, 
        // we'll just return false for simplicity
        return false
    }
}
#endif

extension View {
    // Enhanced customTapAction with optional haptic feedback
    func customTapAction(haptic: HapticStyle = .none, action: @escaping () -> Void) -> some View {
        self.contentShape(Rectangle())
            .gesture(TapGesture()
                .onEnded { _ in
                    // Generate haptic feedback if specified - simpler implementation without try/catch
                    haptic.generateFeedback()
                    
                    // Execute the action
                    action()
                })
    }
} 