import AppKit

public protocol ToolbarViewDelegate: AnyObject {
    func toolbarDidSelectTool(_ tool: ToolType)
    func toolbarDidSelectStrokeWidth(_ width: CGFloat)
    func toolbarDidSelectColor(_ color: NSColor, forSlot slot: ColorSlot)
    func toolbarDidTriggerPaste()
    func toolbarDidTriggerUndo()
    func toolbarDidTriggerRedo()
}

// MARK: - Custom Pressed Tool Button (Windows 11 Fluent Signature Look)
public final class ToolButton: NSButton {
    public override var isFlipped: Bool { return true }

    public var isToolSelected: Bool = false {
        didSet {
            if oldValue != isToolSelected {
                needsDisplay = true
            }
        }
    }

    private var isHovered: Bool = false {
        didSet {
            if oldValue != isHovered {
                needsDisplay = true
            }
        }
    }

    private var isPressedDown: Bool = false {
        didSet {
            if oldValue != isPressedDown {
                needsDisplay = true
            }
        }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.masksToBounds = false

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        isPressedDown = false
    }

    public override func mouseDown(with event: NSEvent) {
        isPressedDown = true
        super.mouseDown(with: event)
        isPressedDown = false
    }

    public override func draw(_ dirtyRect: NSRect) {
        let drawBounds = self.bounds.insetBy(dx: 1.5, dy: 1.5)
        let path = NSBezierPath(roundedRect: drawBounds, xRadius: 5.0, yRadius: 5.0)

        if isToolSelected {
            // Selected / Pressed Active State (Windows 11 Fluent Signature)
            let activeBg = isPressedDown
                ? NSColor(red: 0.72, green: 0.83, blue: 0.95, alpha: 1.0)
                : NSColor(red: 0.80, green: 0.89, blue: 0.98, alpha: 1.0)
            activeBg.setFill()
            path.fill()

            // 1.5px Accent Blue border
            let activeBorder = NSColor(red: 0.0, green: 0.45, blue: 0.88, alpha: 1.0)
            activeBorder.setStroke()
            path.lineWidth = 1.5
            path.stroke()

            // Subtle inner top shadow in flipped coordinates (minY is the top)
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let topShadow = NSBezierPath()
            topShadow.move(to: NSPoint(x: drawBounds.minX, y: drawBounds.minY))
            topShadow.line(to: NSPoint(x: drawBounds.maxX, y: drawBounds.minY))
            topShadow.lineWidth = 2.0
            NSColor(red: 0.0, green: 0.25, blue: 0.60, alpha: 0.18).setStroke()
            topShadow.stroke()
            NSGraphicsContext.restoreGraphicsState()

        } else if isHovered {
            // Hover State
            let hoverBg = isPressedDown
                ? NSColor(calibratedWhite: 0.0, alpha: 0.10)
                : NSColor(calibratedWhite: 0.0, alpha: 0.06)
            hoverBg.setFill()
            path.fill()

            let hoverBorder = NSColor(calibratedWhite: 0.0, alpha: 0.20)
            hoverBorder.setStroke()
            path.lineWidth = 1.0
            path.stroke()

        } else {
            // Inactive State: Clean, subtle 1px border matching Fluent design
            NSColor(calibratedWhite: 1.0, alpha: 0.5).setFill()
            path.fill()

            let normalBorder = NSColor(calibratedWhite: 0.0, alpha: 0.10)
            normalBorder.setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }

        // In flipped coordinates (+y goes down), nudge down by 1px when pressed
        let yNudge: CGFloat = (isToolSelected || isPressedDown) ? 1.0 : 0.0

        if let img = self.image {
            let targetSize = NSSize(width: 20, height: 20)
            let imgRect = NSRect(
                x: round((self.bounds.width - targetSize.width) / 2.0),
                y: round((self.bounds.height - targetSize.height) / 2.0) + yNudge,
                width: targetSize.width,
                height: targetSize.height
            )
            // Use respectFlipped: true to guarantee images are drawn right-side up
            img.draw(
                in: imgRect,
                from: NSRect(origin: .zero, size: img.size),
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: nil
            )
        } else if !title.isEmpty {
            let font = NSFont.boldSystemFont(ofSize: 13)
            let color = isToolSelected ? NSColor(red: 0.0, green: 0.35, blue: 0.75, alpha: 1.0) : NSColor.labelColor
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            let str = title as NSString
            let strSize = str.size(withAttributes: attrs)
            let strRect = NSRect(
                x: round((self.bounds.width - strSize.width) / 2.0),
                y: round((self.bounds.height - strSize.height) / 2.0) + yNudge,
                width: strSize.width,
                height: strSize.height
            )
            str.draw(in: strRect, withAttributes: attrs)
        }
    }
}

// MARK: - Action Button (e.g. Paste)
public final class ActionToolButton: NSButton {
    private var isHovered: Bool = false { didSet { needsDisplay = true } }
    private var isPressedDown: Bool = false { didSet { needsDisplay = true } }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        self.isBordered = false
        self.wantsLayer = true
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        isPressedDown = false
    }

    public override func mouseDown(with event: NSEvent) {
        isPressedDown = true
        super.mouseDown(with: event)
        isPressedDown = false
    }

    public override func draw(_ dirtyRect: NSRect) {
        let drawBounds = self.bounds.insetBy(dx: 1.5, dy: 1.5)
        let path = NSBezierPath(roundedRect: drawBounds, xRadius: 6.0, yRadius: 6.0)

        if isPressedDown {
            NSColor(calibratedWhite: 0.0, alpha: 0.12).setFill()
            path.fill()
            NSColor(calibratedWhite: 0.0, alpha: 0.25).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        } else if isHovered {
            NSColor(calibratedWhite: 0.0, alpha: 0.06).setFill()
            path.fill()
            NSColor(calibratedWhite: 0.0, alpha: 0.18).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        } else {
            NSColor(calibratedWhite: 1.0, alpha: 0.7).setFill()
            path.fill()
            NSColor(calibratedWhite: 0.0, alpha: 0.12).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }

        let yOffset: CGFloat = isPressedDown ? -1.0 : 0.0
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: pStyle
        ]
        let str = title as NSString
        let size = str.size(withAttributes: attrs)
        let rect = NSRect(
            x: round((drawBounds.width - size.width) / 2.0) + drawBounds.origin.x,
            y: round((drawBounds.height - size.height) / 2.0) + drawBounds.origin.y + yOffset,
            width: size.width,
            height: size.height
        )
        str.draw(in: rect, withAttributes: attrs)
    }
}

// MARK: - Toolbar View
public final class ToolbarView: NSView, PaletteViewDelegate, StrokeSizePickerDelegate {
    public weak var delegate: ToolbarViewDelegate?

    private var toolButtons: [ToolType: ToolButton] = [:]
    public let paletteView = PaletteView()
    public let sizePicker = StrokeSizePicker()

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 1100, height: 72))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Fluent / Win11 style light background
        let bg = NSColor(calibratedWhite: 0.96, alpha: 1.0)
        bg.setFill()
        dirtyRect.fill()

        // Bottom border line
        let border = NSColor(calibratedWhite: 0.85, alpha: 1.0)
        border.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: 0))
        path.line(to: NSPoint(x: bounds.width, y: 0))
        path.lineWidth = 1.0
        path.stroke()
    }

    private func setupUI() {
        var currentX: CGFloat = 12

        // 1. Clipboard Group (Paste button)
        let pasteBtn = ActionToolButton()
        pasteBtn.title = "붙여넣기\n⌘V"
        pasteBtn.frame = NSRect(x: currentX, y: 12, width: 70, height: 48)
        pasteBtn.target = self
        pasteBtn.action = #selector(pasteClicked)
        addSubview(pasteBtn)
        currentX += 78

        addSeparator(at: currentX)
        currentX += 12

        // 2. Tools Grid (Select, Pencil, Brush, Eraser, Fill, ColorPicker, Text)
        let primaryTools: [ToolType] = [.select, .pencil, .brush, .eraser, .fill, .colorPicker, .text]
        for tool in primaryTools {
            let btn = createToolButton(tool: tool)
            btn.frame = NSRect(x: currentX, y: 18, width: 36, height: 36)
            addSubview(btn)
            toolButtons[tool] = btn
            currentX += 40
        }

        addSeparator(at: currentX)
        currentX += 12

        // 3. Shapes Grid (Line, Rectangle, RoundedRect, Oval)
        let shapeTools: [ToolType] = [.line, .rectangle, .roundedRect, .oval]
        for shape in shapeTools {
            let btn = createToolButton(tool: shape)
            btn.frame = NSRect(x: currentX, y: 18, width: 36, height: 36)
            addSubview(btn)
            toolButtons[shape] = btn
            currentX += 40
        }

        addSeparator(at: currentX)
        currentX += 12

        // 4. Stroke Size Picker
        let sizeLabel = NSTextField(labelWithString: "굵기:")
        sizeLabel.font = NSFont.systemFont(ofSize: 11)
        sizeLabel.frame = NSRect(x: currentX, y: 44, width: 50, height: 16)
        addSubview(sizeLabel)

        sizePicker.frame = NSRect(x: currentX, y: 18, width: 75, height: 26)
        sizePicker.sizeDelegate = self
        addSubview(sizePicker)
        currentX += 85

        addSeparator(at: currentX)
        currentX += 12

        // 5. Palette View (Colors)
        paletteView.frame = NSRect(x: currentX, y: 6, width: 340, height: 60)
        paletteView.delegate = self
        addSubview(paletteView)

        // Select Pencil by default
        selectToolButton(.pencil)
    }

    private func addSeparator(at x: CGFloat) {
        let sep = NSBox(frame: NSRect(x: x, y: 12, width: 1, height: 48))
        sep.boxType = .separator
        addSubview(sep)
    }

    private func createToolButton(tool: ToolType) -> ToolButton {
        let btn = ToolButton()
        btn.toolTip = "\(tool.displayName) 도구"
        btn.target = self
        btn.action = #selector(toolButtonClicked(_:))
        btn.tag = ToolType.allCases.firstIndex(of: tool) ?? 0

        // Attempt to load extracted SVG icon or fallback to SF Symbol
        if let icon = loadIcon(named: tool.iconName) {
            btn.image = icon
            btn.imagePosition = .imageOnly
            btn.imageScaling = .scaleProportionallyDown
        } else {
            btn.title = String(tool.displayName.prefix(1))
            btn.font = NSFont.boldSystemFont(ofSize: 13)
        }
        return btn
    }

    private func loadIcon(named name: String) -> NSImage? {
        // Custom dedicated vector geometric icons ensuring 100% precision and correct orientation
        switch name {
        case "RoundedRectTool":
            return createRoundedRectIcon()
        case "RectangleTool":
            return createRectIcon()
        case "OvalTool":
            return createOvalIcon()
        case "LineTool":
            return createLineIcon()
        case "TextTool":
            return createTextIcon()
        default:
            break
        }

        // Check bundle resources
        if let bundlePath = Bundle.module.path(forResource: name, ofType: "svg") ?? Bundle.module.path(forResource: name, ofType: "svg", inDirectory: "Icons") {
            if let img = NSImage(contentsOfFile: bundlePath) {
                return img
            }
        }

        // Fallback SF Symbols
        switch name {
        case "PencilTool": return NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        case "BrushIcon": return NSImage(systemSymbolName: "paintbrush", accessibilityDescription: nil)
        case "EraserTool": return NSImage(systemSymbolName: "eraser", accessibilityDescription: nil)
        case "FillTool": return NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)
        case "ColorPickerTool": return NSImage(systemSymbolName: "eyedropper", accessibilityDescription: nil)
        case "RectangularSelectionLarge": return NSImage(systemSymbolName: "viewfinder", accessibilityDescription: nil)
        default: return nil
        }
    }

    private func createRoundedRectIcon() -> NSImage {
        // Symmetrically rounded on all 4 corners (top-left, top-right, bottom-left, bottom-right)
        return NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            let drawRect = NSRect(x: 2.0, y: 3.5, width: 16.0, height: 13.0)
            let path = NSBezierPath(roundedRect: drawRect, xRadius: 4.0, yRadius: 4.0)
            path.lineWidth = 1.3
            NSColor.black.withAlphaComponent(0.85).setStroke()
            path.stroke()
            return true
        }
    }

    private func createRectIcon() -> NSImage {
        return NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            let drawRect = NSRect(x: 2.0, y: 3.5, width: 16.0, height: 13.0)
            let path = NSBezierPath(rect: drawRect)
            path.lineWidth = 1.3
            NSColor.black.withAlphaComponent(0.85).setStroke()
            path.stroke()
            return true
        }
    }

    private func createOvalIcon() -> NSImage {
        return NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            let drawRect = NSRect(x: 2.0, y: 2.5, width: 16.0, height: 15.0)
            let path = NSBezierPath(ovalIn: drawRect)
            path.lineWidth = 1.3
            NSColor.black.withAlphaComponent(0.85).setStroke()
            path.stroke()
            return true
        }
    }

    private func createLineIcon() -> NSImage {
        return NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 3.5, y: 16.5))
            path.line(to: NSPoint(x: 16.5, y: 3.5))
            path.lineWidth = 1.4
            path.lineCapStyle = .round
            NSColor.black.withAlphaComponent(0.85).setStroke()
            path.stroke()
            return true
        }
    }

    private func createTextIcon() -> NSImage {
        if let sf = NSImage(systemSymbolName: "textformat", accessibilityDescription: nil) {
            return sf
        }
        return NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.black.withAlphaComponent(0.88)
            ]
            let str = "가가" as NSString
            let size = str.size(withAttributes: attrs)
            let origin = NSPoint(
                x: round((rect.width - size.width) / 2.0),
                y: round((rect.height - size.height) / 2.0)
            )
            str.draw(at: origin, withAttributes: attrs)
            return true
        }
    }

    @objc private func toolButtonClicked(_ sender: ToolButton) {
        guard sender.tag >= 0 && sender.tag < ToolType.allCases.count else { return }
        let tool = ToolType.allCases[sender.tag]
        selectToolButton(tool)
        delegate?.toolbarDidSelectTool(tool)
    }

    public func selectToolButton(_ tool: ToolType) {
        for (t, btn) in toolButtons {
            btn.isToolSelected = (t == tool)
        }
    }

    @objc private func pasteClicked() {
        delegate?.toolbarDidTriggerPaste()
    }

    // MARK: - Delegates
    public func strokeSizePickerDidSelectWidth(_ width: CGFloat) {
        delegate?.toolbarDidSelectStrokeWidth(width)
    }

    public func paletteDidSelectColor(_ color: NSColor, forSlot slot: ColorSlot) {
        delegate?.toolbarDidSelectColor(color, forSlot: slot)
    }
}
