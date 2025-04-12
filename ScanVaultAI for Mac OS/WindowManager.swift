import Foundation
import Combine
import SwiftUI

/// Manages windows and their states in the application
class WindowManager: ObservableObject {
    /// Enum representing different window types in the application
    enum WindowType: String, Identifiable {
        case main
        case settings
        case documentViewer
        case search
        
        var id: String { self.rawValue }
    }
    
    /// Tracks which windows are currently open
    @Published var openWindows: Set<WindowType> = [.main]
    
    /// The currently active window
    @Published var activeWindow: WindowType = .main
    
    /// Window positions as a dictionary mapping window types to CGRect
    @Published var windowPositions: [WindowType: CGRect] = [:]
    
    /// Initialize with default state of only main window open
    init() {
        // Default initialization
    }
    
    /// Open a window of the specified type
    /// - Parameter type: The window type to open
    func openWindow(_ type: WindowType) {
        openWindows.insert(type)
        activeWindow = type
    }
    
    /// Close a window of the specified type
    /// - Parameter type: The window type to close
    func closeWindow(_ type: WindowType) {
        // Don't allow closing the main window
        guard type != .main else { return }
        openWindows.remove(type)
        
        // If we closed the active window, activate the main window
        if activeWindow == type {
            activeWindow = .main
        }
    }
    
    /// Set a window as the active window
    /// - Parameter type: The window type to activate
    func activateWindow(_ type: WindowType) {
        if openWindows.contains(type) {
            activeWindow = type
        } else {
            // If the window isn't open, open it and make it active
            openWindow(type)
        }
    }
    
    /// Save the position of a window
    /// - Parameters:
    ///   - type: The window type
    ///   - rect: The window's position and size
    func saveWindowPosition(_ type: WindowType, rect: CGRect) {
        windowPositions[type] = rect
    }
    
    /// Get the saved position for a window
    /// - Parameter type: The window type
    /// - Returns: The saved position, or nil if no position is saved
    func getWindowPosition(_ type: WindowType) -> CGRect? {
        return windowPositions[type]
    }
} 