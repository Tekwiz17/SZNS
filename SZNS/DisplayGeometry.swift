import Foundation
import CoreGraphics

enum DockSide { case bottom, left, right }

struct DisplayGeometry {
    // Quartz and Accessibility measure downward from the primary display's top edge.
    static func cocoa(_ ax: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: ax.minX, y: primaryHeight - ax.maxY, width: ax.width, height: ax.height)
    }
    static func dockStrip(_ dock: CGRect, screen: CGRect, depth: CGFloat) -> (CGRect, DockSide)? {
        let visible = dock.intersection(screen)
        guard !visible.isNull, min(visible.width, visible.height) >= 5 else { return nil }
        if dock.width >= dock.height {
            return (CGRect(x: visible.minX, y: visible.maxY - depth, width: visible.width, height: depth), .bottom)
        }
        if visible.midX < screen.midX {
            return (CGRect(x: visible.maxX - depth, y: visible.minY, width: depth, height: visible.height), .left)
        }
        return (CGRect(x: visible.minX, y: visible.minY, width: depth, height: visible.height), .right)
    }
}
