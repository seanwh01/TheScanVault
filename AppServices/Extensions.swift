import Foundation

// MARK: - Safe Numeric Conversions

extension BinaryFloatingPoint {
    /// Safely converts a floating point value to Int, handling infinities and NaN
    /// Returns 0 for NaN or infinity values, and respects Int min/max boundaries
    var safeIntValue: Int {
        // Handle non-finite values
        guard self.isFinite else { return 0 }
        guard !self.isNaN else { return 0 }
        
        // Handle values outside Int range
        if self > Self(Int.max) { return Int.max }
        if self < Self(Int.min) { return Int.min }
        
        // Normal case - safe to convert
        return Int(self)
    }
}

// MARK: - Other Extensions

// Add other extensions as needed 