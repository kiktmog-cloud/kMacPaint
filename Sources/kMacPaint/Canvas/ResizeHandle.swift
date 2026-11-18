import AppKit

public enum ResizeHandleType {
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var cursor: NSCursor {
        switch self {
        case .left, .right:
            return NSCursor.resizeLeftRight
        case .top, .bottom:
            return NSCursor.resizeUpDown
        case .topLeft, .bottomRight, .topRight, .bottomLeft:
            return NSCursor.crosshair
        }
    }
}

public struct ResizeHandle {
    public static let size: CGFloat = 8.0

    public let type: ResizeHandleType
    public let rect: CGRect

    public init(type: ResizeHandleType, canvasRect: CGRect) {
        self.type = type
        let half = ResizeHandle.size / 2.0
        
        switch type {
        case .left:
            self.rect = CGRect(
                x: canvasRect.minX - half,
                y: canvasRect.midY - half,
                width: ResizeHandle.size,
                height: ResizeHandle.size
            )
        case .right:
            self.rect = CGRect(
                x: canvasRect.maxX - half,
                y: canvasRect.midY - half,
                width: ResizeHandle.size,
                height: ResizeHandle.size
            )
        case .top:
            self.rect = CGRect(
                x: canvasRect.midX - half,
                y: canvasRect.minY - half,
                width: ResizeHandle.size,
                height: ResizeHandle.size
            )
        case .bottom:
            self.rect = CGRect(
                x: canvasRect.midX - half,
                y: canvasRect.maxY - half,
                width: ResizeHandle.size,
                height: ResizeHandle.size
            )
        case .topLeft:
            self.rect = CGRect(
                x: canvasRect.minX - half,
                y: canvasRect.minY - half,
                width: ResizeHandle.size,
                height: ResizeHandle.size
            )
        case .topRight:
            self.rect = CGRect(
                x: canvasRect.maxX - half,
                y: canvasRect.minY - half,
                width: ResizeHandle.size,
                height: ResizeHandle.size
            )
        case .bottomLeft:
            self.rect = CGRect(
                x: canvasRect.minX - half,
                y: canvasRect.maxY - half,
                width: ResizeHandle.size,
                height: ResizeHandle.size
            )
        case .bottomRight:
            self.rect = CGRect(
                x: canvasRect.maxX - half,
                y: canvasRect.maxY - half,
                width: ResizeHandle.size,
                height: ResizeHandle.size
            )
        }
    }

    public func contains(_ point: CGPoint) -> Bool {
        // Generous touch hit test (extra padding)
        return rect.insetBy(dx: -4, dy: -4).contains(point)
    }

    public func draw() {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw white fill with gray/blue border (Windows 11 Paint style)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)

        context.setStrokeColor(NSColor(calibratedWhite: 0.3, alpha: 1.0).cgColor)
        context.setLineWidth(1.0)
        context.stroke(rect)
    }
}
