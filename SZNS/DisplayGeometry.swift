import Foundation
import CoreGraphics

enum DockSide: String { case bottom, left, right }

struct DockDisplay {
    let frame: CGRect
    let usable: CGRect

    func reservedDepth(_ side: DockSide) -> CGFloat {
        switch side {
        case .bottom: return usable.minY - frame.minY
        case .left: return usable.minX - frame.minX
        case .right: return frame.maxX - usable.maxX
        }
    }

    // Input is in AppKit points, including displays above or left of the primary.
    func dockBounds(_ candidate: CGRect, side: DockSide, useReservedEdge: Bool) -> CGRect? {
        let clipped = frame.intersection(candidate)
        guard !clipped.isNull, !clipped.isEmpty else { return nil }
        let horizontal = side == .bottom
        let thickness = horizontal ? clipped.height : clipped.width
        let length = horizontal ? clipped.width : clipped.height
        let maxThickness = min(240, (horizontal ? frame.height : frame.width) * 0.32)
        guard thickness >= 5, thickness <= maxThickness, length >= max(24, thickness * 1.25),
              (horizontal ? candidate.height : candidate.width) <= maxThickness else { return nil }
        let gap: CGFloat
        switch side {
        case .bottom: gap = clipped.minY - frame.minY
        case .left: gap = clipped.minX - frame.minX
        case .right: gap = frame.maxX - clipped.maxX
        }
        let reserved = reservedDepth(side)
        // Item bounds can sit several points inside the Dock glass.
        guard gap <= 18 || (reserved >= 16 && gap < reserved * 0.55) else { return nil }
        let depth = useReservedEdge && reserved >= 16 ? reserved : gap + thickness
        switch side {
        case .bottom: return CGRect(x: clipped.minX, y: frame.minY, width: length, height: depth)
        case .left: return CGRect(x: frame.minX, y: clipped.minY, width: depth, height: length)
        case .right: return CGRect(x: frame.maxX - depth, y: clipped.minY, width: depth, height: length)
        }
    }
}

struct DisplayGeometry {
    static func cocoa(_ quartz: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: quartz.minX, y: primaryHeight - quartz.maxY, width: quartz.width, height: quartz.height)
    }

    // Use the largest intersection, including during a partially revealed Dock animation.
    static func dockDisplay(for rect: CGRect, in displays: [DockDisplay]) -> DockDisplay? {
        displays.filter { $0.frame.intersects(rect) }.max { a, b in
            let x = a.frame.intersection(rect), y = b.frame.intersection(rect)
            return x.width * x.height < y.width * y.height
        }
    }

    static func dockStrip(_ dock: CGRect, screen: CGRect, depth: CGFloat) -> (CGRect, DockSide)? {
        let visible = dock.intersection(screen)
        guard !visible.isNull, min(visible.width, visible.height) >= 5 else { return nil }
        if dock.width >= dock.height {
            let h = min(depth, visible.height)
            return (CGRect(x: visible.minX, y: visible.maxY - h, width: visible.width, height: h), .bottom)
        }
        let w = min(depth, visible.width)
        if visible.midX < screen.midX {
            return (CGRect(x: visible.maxX - w, y: visible.minY, width: w, height: visible.height), .left)
        }
        return (CGRect(x: visible.minX, y: visible.minY, width: w, height: visible.height), .right)
    }
}
