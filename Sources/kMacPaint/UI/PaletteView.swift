import AppKit

public protocol PaletteViewDelegate: AnyObject {
    func paletteDidSelectColor(_ color: NSColor, forSlot slot: ColorSlot)
}

public enum ColorSlot {
    case primary    // Color 1
    case secondary  // Color 2
}

public final class PaletteView: NSView {
    public weak var delegate: PaletteViewDelegate?

    public var activeSlot: ColorSlot = .primary {
        didSet { needsDisplay = true }
    }
    public var primaryColor: NSColor = .black {
        didSet { needsDisplay = true }
    }
    public var secondaryColor: NSColor = .white {
        didSet { needsDisplay = true }
    }

    // Windows 11 Paint Signature 20-Color Grid
    public static let defaultColors: [NSColor] = [
        // Row 1
        NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),       // Black
        NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),       // Gray
        NSColor(srgbRed: 0.53, green: 0.0, blue: 0.08, alpha: 1.0),     // Dark Red
        NSColor(srgbRed: 0.93, green: 0.11, blue: 0.14, alpha: 1.0),    // Red
        NSColor(srgbRed: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),       // Orange
        NSColor(srgbRed: 1.0, green: 0.95, blue: 0.0, alpha: 1.0),      // Yellow
        NSColor(srgbRed: 0.13, green: 0.69, blue: 0.3, alpha: 1.0),     // Green
        NSColor(srgbRed: 0.0, green: 0.64, blue: 0.91, alpha: 1.0),     // Turquoise
        NSColor(srgbRed: 0.24, green: 0.35, blue: 0.67, alpha: 1.0),    // Indigo
        NSColor(srgbRed: 0.64, green: 0.29, blue: 0.64, alpha: 1.0),    // Purple

        // Row 2
        NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),       // White
        NSColor(srgbRed: 0.78, green: 0.78, blue: 0.78, alpha: 1.0),   // Light Gray
        NSColor(srgbRed: 0.72, green: 0.53, blue: 0.44, alpha: 1.0),   // Brown
        NSColor(srgbRed: 1.0, green: 0.68, blue: 0.79, alpha: 1.0),     // Rose
        NSColor(srgbRed: 1.0, green: 0.79, blue: 0.05, alpha: 1.0),    // Gold
        NSColor(srgbRed: 0.94, green: 0.90, blue: 0.55, alpha: 1.0),   // Light Yellow
        NSColor(srgbRed: 0.71, green: 0.90, blue: 0.11, alpha: 1.0),   // Lime
        NSColor(srgbRed: 0.60, green: 0.85, blue: 0.92, alpha: 1.0),   // Light Turquoise
        NSColor(srgbRed: 0.44, green: 0.58, blue: 0.86, alpha: 1.0),   // Steel Blue
        NSColor(srgbRed: 0.79, green: 0.75, blue: 0.87, alpha: 1.0)    // Lavender
    ]

    private var slot1Rect: NSRect = .zero
    private var slot2Rect: NSRect = .zero
    private var colorSwatches: [(NSRect, NSColor)] = []
    private var editColorRect: NSRect = .zero

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 330, height: 60))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Layout:
        // Left: Color 1 (30x30) + Color 2 (30x30)
        // Middle: 10 x 2 Grid of swatches (16x16 each)
        // Right: Edit Colors button
        
        slot1Rect = NSRect(x: 8, y: 14, width: 34, height: 34)
        slot2Rect = NSRect(x: 48, y: 14, width: 34, height: 34)

        // Draw Color 1 Box
        drawColorBox(rect: slot1Rect, color: primaryColor, isSelected: activeSlot == .primary, label: "1", in: ctx)
        // Draw Color 2 Box
        drawColorBox(rect: slot2Rect, color: secondaryColor, isSelected: activeSlot == .secondary, label: "2", in: ctx)

        // Draw 10x2 Swatch Grid
        colorSwatches.removeAll()
        let startX: CGFloat = 94
        let swatchW: CGFloat = 16
        let swatchH: CGFloat = 16
        let spacing: CGFloat = 3

        for i in 0..<Self.defaultColors.count {
            let col = i % 10
            let row = i / 10
            let x = startX + CGFloat(col) * (swatchW + spacing)
            // Row 0 is top, Row 1 is bottom
            let y = bounds.height - 24 - CGFloat(row) * (swatchH + spacing)
            let rect = NSRect(x: x, y: y, width: swatchW, height: swatchH)
            let color = Self.defaultColors[i]

            colorSwatches.append((rect, color))

            ctx.setFillColor(color.cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(NSColor(calibratedWhite: 0.7, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.0)
            ctx.stroke(rect)
        }

        // Draw Edit Colors Button (Right)
        editColorRect = NSRect(x: startX + 10 * (swatchW + spacing) + 8, y: 14, width: 32, height: 34)
        ctx.setFillColor(NSColor(calibratedWhite: 0.94, alpha: 1.0).cgColor)
        ctx.fill(editColorRect)
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.75, alpha: 1.0).cgColor)
        ctx.stroke(editColorRect)

        let str = "🎨"
        let font = NSFont.systemFont(ofSize: 16)
        let attr: [NSAttributedString.Key: Any] = [.font: font]
        let astr = NSAttributedString(string: str, attributes: attr)
        astr.draw(at: NSPoint(x: editColorRect.origin.x + 6, y: editColorRect.origin.y + 6))
    }

    private func drawColorBox(rect: NSRect, color: NSColor, isSelected: Bool, label: String, in ctx: CGContext) {
        // Outer selection border
        if isSelected {
            ctx.setStrokeColor(NSColor.systemBlue.cgColor)
            ctx.setLineWidth(2.5)
            ctx.stroke(rect.insetBy(dx: -2, dy: -2))
        } else {
            ctx.setStrokeColor(NSColor(calibratedWhite: 0.75, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.0)
            ctx.stroke(rect)
        }

        // Fill color
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)

        // Inner 1px border for white visibility
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.8, alpha: 0.8).cgColor)
        ctx.setLineWidth(1.0)
        ctx.stroke(rect)

        // Label (1 or 2)
        let font = NSFont.boldSystemFont(ofSize: 10)
        let rgbColor = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB)
        let luminance: CGFloat
        if let rgb = rgbColor {
            luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        } else {
            luminance = 0.0
        }
        let textColor = (luminance < 0.5) ? NSColor.white : NSColor.black
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let astr = NSAttributedString(string: label, attributes: attr)
        astr.draw(at: NSPoint(x: rect.origin.x + 3, y: rect.origin.y + 2))
    }

    public override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        if slot1Rect.contains(pt) {
            activeSlot = .primary
            needsDisplay = true
            return
        }
        if slot2Rect.contains(pt) {
            activeSlot = .secondary
            needsDisplay = true
            return
        }

        for (rect, color) in colorSwatches {
            if rect.contains(pt) {
                if activeSlot == .primary {
                    primaryColor = color
                } else {
                    secondaryColor = color
                }
                delegate?.paletteDidSelectColor(color, forSlot: activeSlot)
                needsDisplay = true
                return
            }
        }

        if editColorRect.contains(pt) {
            openSystemColorPanel()
            return
        }
    }

    private func openSystemColorPanel() {
        let panel = NSColorPanel.shared
        panel.color = (activeSlot == .primary) ? primaryColor : secondaryColor
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.orderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        let color = sender.color
        if activeSlot == .primary {
            primaryColor = color
        } else {
            secondaryColor = color
        }
        delegate?.paletteDidSelectColor(color, forSlot: activeSlot)
        needsDisplay = true
    }
}
