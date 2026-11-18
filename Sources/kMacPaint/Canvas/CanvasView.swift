import AppKit

public protocol CanvasViewDelegate: AnyObject {
    func canvasDidUpdateSize(_ size: CGSize)
    func canvasDidUpdateCursorPosition(_ point: CGPoint)
    func canvasDidPickColor(_ color: NSColor)
    func canvasDidChangeTool(_ tool: ToolType)
}

public final class CanvasView: NSView, InlineTextEditorDelegate {
    public override var isFlipped: Bool { return true }

    public let model: CanvasModel
    public weak var delegate: CanvasViewDelegate?

    // Active Tool Configuration
    public var currentTool: ToolType = .pencil {
        didSet {
            if oldValue != currentTool {
                delegate?.canvasDidChangeTool(currentTool)
            }
        }
    }
    public var primaryColor: NSColor = .black {
        didSet {
            activeTextEditor?.textColor = primaryColor
        }
    }
    public var secondaryColor: NSColor = .white
    public var strokeWidth: CGFloat = 3.0

    // Floating Selection (Image overlay / pasted image)
    public var floatingSelection: FloatingSelection?

    // Inline Text Editor
    public var activeTextEditor: InlineTextEditor?

    // Workspace Margins around Canvas (ensures center positioning and ample space for 8 handles)
    public var canvasMarginX: CGFloat = 80.0
    public var canvasMarginY: CGFloat = 60.0

    public var canvasOrigin: CGPoint {
        return CGPoint(x: canvasMarginX, y: canvasMarginY)
    }

    public var canvasRect: CGRect {
        return CGRect(origin: canvasOrigin, size: model.size)
    }

    // Canvas Resize Dragging State
    private var activeResizeHandle: ResizeHandleType?
    private var resizePreviewFrame: CGRect?

    // Tool Drawing Dragging State
    private var isDrawing: Bool = false
    private var startPoint: CGPoint = .zero
    private var lastPoint: CGPoint = .zero
    private var currentShapePreviewRect: CGRect?

    // Marquee Selection Dragging State
    private var isSelectingMarquee: Bool = false
    private var marqueeStartPoint: CGPoint = .zero
    private var marqueeRect: CGRect = .zero

    // 8 Directional Handles
    private var handles: [ResizeHandle] {
        return [
            ResizeHandle(type: .topLeft, canvasRect: canvasRect),
            ResizeHandle(type: .top, canvasRect: canvasRect),
            ResizeHandle(type: .topRight, canvasRect: canvasRect),
            ResizeHandle(type: .left, canvasRect: canvasRect),
            ResizeHandle(type: .right, canvasRect: canvasRect),
            ResizeHandle(type: .bottomLeft, canvasRect: canvasRect),
            ResizeHandle(type: .bottom, canvasRect: canvasRect),
            ResizeHandle(type: .bottomRight, canvasRect: canvasRect)
        ]
    }

    public init(model: CanvasModel) {
        self.model = model
        super.init(frame: NSRect(origin: .zero, size: model.size))
        
        self.model.onChange = { [weak self] in
            guard let self = self else { return }
            self.updateFrameSize()
            self.needsDisplay = true
            self.delegate?.canvasDidUpdateSize(self.model.size)
        }
        
        // Enable tracking area for mouse hover / cursor updates
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)

        updateFrameSize()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateFrameSize() {
        let visibleSize = enclosingScrollView?.contentView.bounds.size ?? CGSize(width: 1000, height: 700)
        canvasMarginX = max(80.0, (visibleSize.width - model.size.width) / 2.0)
        canvasMarginY = max(60.0, (visibleSize.height - model.size.height) / 2.0)

        let totalW = model.size.width + canvasMarginX * 2.0
        let totalH = model.size.height + canvasMarginY * 2.0
        let newFrame = NSRect(x: 0, y: 0, width: totalW, height: totalH)
        if self.frame != newFrame {
            self.frame = newFrame
        }
    }

    public func toCanvasPoint(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x - canvasOrigin.x, y: point.y - canvasOrigin.y)
    }

    // MARK: - Drawing & Rendering
    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Workspace Background Fill
        NSColor(calibratedWhite: 0.88, alpha: 1.0).setFill()
        dirtyRect.fill()

        // 2. Draw Canvas Drop Shadow & White Background
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: NSColor(calibratedWhite: 0, alpha: 0.22).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(canvasRect)
        context.restoreGState()

        // 3. Draw Main Canvas Image
        if let cgImage = model.currentCGImage() {
            context.saveGState()
            context.clip(to: canvasRect)
            context.translateBy(x: canvasOrigin.x, y: canvasOrigin.y + model.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(cgImage, in: CGRect(origin: .zero, size: model.size))
            context.restoreGState()
        }

        // 4. Draw Rubber-band Shape Preview (if actively drawing shape)
        if isDrawing, let previewRect = currentShapePreviewRect {
            context.saveGState()
            context.clip(to: canvasRect)
            context.translateBy(x: canvasOrigin.x, y: canvasOrigin.y)
            context.setStrokeColor(primaryColor.cgColor)
            context.setLineWidth(strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            switch currentTool {
            case .line:
                context.beginPath()
                context.move(to: startPoint)
                context.addLine(to: lastPoint)
                context.strokePath()
            case .rectangle:
                context.stroke(previewRect)
            case .roundedRect:
                let path = CGPath(roundedRect: previewRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                context.addPath(path)
                context.strokePath()
            case .oval:
                context.strokeEllipse(in: previewRect)
            default:
                break
            }
            context.restoreGState()
        }

        // 5. Draw Floating Selection (Pasted / Loaded Image Overlay)
        if let selection = floatingSelection {
            context.saveGState()
            context.translateBy(x: canvasOrigin.x, y: canvasOrigin.y)
            selection.draw()
            context.restoreGState()
        }

        // 5.5 Draw Marquee Selection Preview
        if isSelectingMarquee && marqueeRect.width > 1 && marqueeRect.height > 1 {
            context.saveGState()
            context.translateBy(x: canvasOrigin.x, y: canvasOrigin.y)

            // Translucent selection blue tint
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.12).cgColor)
            context.fill(marqueeRect)

            // High-contrast marching ants / dashed border
            context.setLineWidth(1.0)
            context.setLineDash(phase: 0, lengths: [4, 4])
            context.setStrokeColor(NSColor.black.cgColor)
            context.stroke(marqueeRect)

            context.setLineDash(phase: 4, lengths: [4, 4])
            context.setStrokeColor(NSColor.white.cgColor)
            context.stroke(marqueeRect)

            context.restoreGState()
        }

        // 6. Draw 8 Canvas Resize Handles (Left, Right, Top, Bottom, and 4 corners)
        for handle in handles {
            handle.draw()
        }

        // 7. Draw Canvas Resize Guide line when dragging any handle
        if let preview = resizePreviewFrame {
            context.saveGState()

            // Extension guide background tint
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.08).cgColor)
            context.fill(preview)

            // Double dashed border (blue + white)
            context.setLineDash(phase: 0, lengths: [6, 4])
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2.5)
            context.stroke(preview)

            context.setLineDash(phase: 5, lengths: [6, 4])
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1.5)
            context.stroke(preview)

            context.restoreGState()
        }
    }

    // MARK: - Floating Selection Actions
    public func pasteImage(_ image: NSImage) {
        commitFloatingSelection() // Bake any existing selection first

        // Center pasted / loaded image on the canvas
        let imgW = image.size.width
        let imgH = image.size.height
        let originX = max(0, (model.size.width - imgW) / 2.0)
        let originY = max(0, (model.size.height - imgH) / 2.0)
        let origin = CGPoint(x: originX, y: originY)

        let selection = FloatingSelection(image: image, origin: origin, originalRect: nil, isLifted: true)
        self.floatingSelection = selection
        self.currentTool = .select
        self.needsDisplay = true
    }

    public func commitFloatingSelection() {
        guard let selection = floatingSelection else { return }
        if selection.isLifted {
            selection.bake(into: model.context)
            model.pushUndoState()
        }
        self.floatingSelection = nil
        self.needsDisplay = true
    }

    public func discardFloatingSelection() {
        self.floatingSelection = nil
        self.needsDisplay = true
    }

    // MARK: - Mouse Event Handling
    public override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let canvasPoint = toCanvasPoint(point)
        delegate?.canvasDidUpdateCursorPosition(canvasPoint)

        // Floating Selection routing
        if let selection = floatingSelection {
            if let handle = selection.hitTest(canvasPoint) {
                switch handle {
                case .body:
                    NSCursor.openHand.set()
                case .topLeft, .bottomRight, .topRight, .bottomLeft:
                    NSCursor.crosshair.set()
                case .top, .bottom:
                    NSCursor.resizeUpDown.set()
                case .left, .right:
                    NSCursor.resizeLeftRight.set()
                }
                return
            }
        }

        // Handles routing
        for handle in handles {
            if handle.contains(point) {
                handle.type.cursor.set()
                return
            }
        }

        // Canvas Area routing
        if canvasRect.contains(point) {
            switch currentTool {
            case .colorPicker:
                NSCursor.crosshair.set()
            case .fill:
                NSCursor.pointingHand.set()
            case .select:
                NSCursor.crosshair.set()
            default:
                NSCursor.crosshair.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let canvasPoint = toCanvasPoint(point)
        startPoint = canvasPoint
        lastPoint = canvasPoint

        // If inline text editing is active and user clicked outside, commit it
        if let editor = activeTextEditor {
            let editorPoint = editor.convert(point, from: self)
            if editor.hitTest(editorPoint) == nil {
                commitInlineText()
            } else {
                return
            }
        }

        // 1. Check 8 Canvas Resize Handles
        for handle in handles {
            if handle.contains(point) {
                activeResizeHandle = handle.type
                resizePreviewFrame = canvasRect
                return
            }
        }

        // 2. Check Floating Selection Interaction
        if let selection = floatingSelection {
            if let hit = selection.hitTest(canvasPoint) {
                selection.activeHandle = hit
                lastPoint = canvasPoint
                return
            } else {
                commitFloatingSelection()
            }
        }

        // 3. Normal Tool Execution
        guard canvasRect.contains(point) else { return }

        switch currentTool {
        case .colorPicker:
            pickColor(at: canvasPoint)
        case .fill:
            FloodFill.execute(context: model.context, point: canvasPoint, fillColor: primaryColor)
            model.pushUndoState()
            needsDisplay = true
        case .pencil, .brush, .eraser:
            isDrawing = true
            drawLineSegment(from: startPoint, to: canvasPoint)
        case .line, .rectangle, .roundedRect, .oval:
            isDrawing = true
            currentShapePreviewRect = CGRect(origin: canvasPoint, size: .zero)
        case .select:
            isSelectingMarquee = true
            marqueeStartPoint = canvasPoint
            marqueeRect = CGRect(origin: canvasPoint, size: .zero)
            needsDisplay = true
        case .text:
            startInlineTextEditor(at: canvasPoint)
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let canvasPoint = toCanvasPoint(point)
        delegate?.canvasDidUpdateCursorPosition(canvasPoint)

        // 1. Canvas Resize Dragging (Supports all 8 directions)
        if let resizeHandle = activeResizeHandle {
            var minX = canvasRect.minX
            var maxX = canvasRect.maxX
            var minY = canvasRect.minY
            var maxY = canvasRect.maxY

            switch resizeHandle {
            case .left:
                minX = min(point.x, canvasRect.maxX - 20)
            case .right:
                maxX = max(point.x, canvasRect.minX + 20)
            case .top:
                minY = min(point.y, canvasRect.maxY - 20)
            case .bottom:
                maxY = max(point.y, canvasRect.minY + 20)
            case .topLeft:
                minX = min(point.x, canvasRect.maxX - 20)
                minY = min(point.y, canvasRect.maxY - 20)
            case .topRight:
                maxX = max(point.x, canvasRect.minX + 20)
                minY = min(point.y, canvasRect.maxY - 20)
            case .bottomLeft:
                minX = min(point.x, canvasRect.maxX - 20)
                maxY = max(point.y, canvasRect.minY + 20)
            case .bottomRight:
                maxX = max(point.x, canvasRect.minX + 20)
                maxY = max(point.y, canvasRect.minY + 20)
            }

            let preview = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            resizePreviewFrame = preview

            // Expand view frame if preview extends beyond bounds so preview is never clipped
            let maxW = max(frame.width, preview.maxX + 60)
            let maxH = max(frame.height, preview.maxY + 60)
            if maxW > frame.width || maxH > frame.height {
                self.frame = CGRect(x: 0, y: 0, width: maxW, height: maxH)
            }

            delegate?.canvasDidUpdateSize(CGSize(width: preview.width, height: preview.height))
            needsDisplay = true
            return
        }

        // 2. Marquee Selection Dragging
        if isSelectingMarquee {
            let minX = max(0, min(marqueeStartPoint.x, canvasPoint.x))
            let minY = max(0, min(marqueeStartPoint.y, canvasPoint.y))
            let maxX = min(model.size.width, max(marqueeStartPoint.x, canvasPoint.x))
            let maxY = min(model.size.height, max(marqueeStartPoint.y, canvasPoint.y))
            marqueeRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            needsDisplay = true
            return
        }

        // 3. Floating Selection Dragging / Resizing
        if let selection = floatingSelection, let handle = selection.activeHandle {
            // Lazy lift: clear original area with secondaryColor when first moved/resized
            if !selection.isLifted {
                if let orig = selection.originalRect {
                    fillCanvasRect(orig, with: secondaryColor)
                }
                selection.isLifted = true
                model.pushUndoState()
            }

            let dx = canvasPoint.x - lastPoint.x
            let dy = canvasPoint.y - lastPoint.y

            if handle == .body {
                selection.frame.origin.x += dx
                selection.frame.origin.y += dy
            } else {
                var f = selection.frame
                switch handle {
                case .right:
                    f.size.width = max(10, f.size.width + dx)
                case .bottom:
                    f.size.height = max(10, f.size.height + dy)
                case .bottomRight:
                    f.size.width = max(10, f.size.width + dx)
                    f.size.height = max(10, f.size.height + dy)
                case .left:
                    let newW = max(10, f.size.width - dx)
                    f.origin.x += (f.size.width - newW)
                    f.size.width = newW
                case .top:
                    let newH = max(10, f.size.height - dy)
                    f.origin.y += (f.size.height - newH)
                    f.size.height = newH
                case .topLeft:
                    let newW = max(10, f.size.width - dx)
                    let newH = max(10, f.size.height - dy)
                    f.origin.x += (f.size.width - newW)
                    f.origin.y += (f.size.height - newH)
                    f.size.width = newW
                    f.size.height = newH
                case .topRight:
                    let newH = max(10, f.size.height - dy)
                    f.origin.y += (f.size.height - newH)
                    f.size.height = newH
                    f.size.width = max(10, f.size.width + dx)
                case .bottomLeft:
                    let newW = max(10, f.size.width - dx)
                    f.origin.x += (f.size.width - newW)
                    f.size.width = newW
                    f.size.height = max(10, f.size.height + dy)
                case .body:
                    break
                }
                selection.frame = f
            }
            lastPoint = canvasPoint
            needsDisplay = true
            return
        }

        // 3. Normal Tool Dragging
        guard isDrawing else { return }

        let isShift = event.modifierFlags.contains(.shift)

        switch currentTool {
        case .pencil, .brush, .eraser:
            drawLineSegment(from: lastPoint, to: canvasPoint)
            lastPoint = canvasPoint
        case .line:
            if isShift {
                let dx = canvasPoint.x - startPoint.x
                let dy = canvasPoint.y - startPoint.y
                let angle = atan2(dy, dx)
                let step = CGFloat.pi / 4.0 // 45 degree snap
                let snappedAngle = round(angle / step) * step
                let dist = hypot(dx, dy)
                lastPoint = CGPoint(
                    x: startPoint.x + dist * cos(snappedAngle),
                    y: startPoint.y + dist * sin(snappedAngle)
                )
            } else {
                lastPoint = canvasPoint
            }
            needsDisplay = true
        case .rectangle, .roundedRect, .oval:
            lastPoint = canvasPoint
            var w = abs(canvasPoint.x - startPoint.x)
            var h = abs(canvasPoint.y - startPoint.y)
            if isShift {
                let side = max(w, h)
                w = side
                h = side
            }
            let x = (canvasPoint.x >= startPoint.x) ? startPoint.x : (startPoint.x - w)
            let y = (canvasPoint.y >= startPoint.y) ? startPoint.y : (startPoint.y - h)
            currentShapePreviewRect = CGRect(x: x, y: y, width: w, height: h)
            needsDisplay = true
        default:
            break
        }
    }

    public override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        if isDrawing {
            let isShift = event.modifierFlags.contains(.shift)
            switch currentTool {
            case .line:
                if isShift {
                    let dx = lastPoint.x - startPoint.x
                    let dy = lastPoint.y - startPoint.y
                    let angle = atan2(dy, dx)
                    let step = CGFloat.pi / 4.0
                    let snappedAngle = round(angle / step) * step
                    let dist = hypot(dx, dy)
                    lastPoint = CGPoint(
                        x: startPoint.x + dist * cos(snappedAngle),
                        y: startPoint.y + dist * sin(snappedAngle)
                    )
                }
                needsDisplay = true
            case .rectangle, .roundedRect, .oval:
                var w = abs(lastPoint.x - startPoint.x)
                var h = abs(lastPoint.y - startPoint.y)
                if isShift {
                    let side = max(w, h)
                    w = side
                    h = side
                }
                let x = (lastPoint.x >= startPoint.x) ? startPoint.x : (startPoint.x - w)
                let y = (lastPoint.y >= startPoint.y) ? startPoint.y : (startPoint.y - h)
                currentShapePreviewRect = CGRect(x: x, y: y, width: w, height: h)
                needsDisplay = true
            default:
                break
            }
        }
    }

    public override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            guard let scrollView = enclosingScrollView else { return }
            let dy = event.deltaY
            if dy != 0 {
                let zoomFactor: CGFloat = dy > 0 ? 1.1 : 0.9
                let newMag = min(max(scrollView.magnification * zoomFactor, scrollView.minMagnification), scrollView.maxMagnification)
                let mousePoint = convert(event.locationInWindow, from: nil)
                scrollView.setMagnification(newMag, centeredAt: mousePoint)
                NotificationCenter.default.post(name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView)
                return
            }
        }
        super.scrollWheel(with: event)
    }

    public override func magnify(with event: NSEvent) {
        guard let scrollView = enclosingScrollView else {
            super.magnify(with: event)
            return
        }
        let currentMag = scrollView.magnification
        let factor = 1.0 + event.magnification
        let newMag = min(max(currentMag * factor, scrollView.minMagnification), scrollView.maxMagnification)
        let mousePoint = convert(event.locationInWindow, from: nil)
        scrollView.setMagnification(newMag, centeredAt: mousePoint)
        NotificationCenter.default.post(name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView)
    }

    public override func mouseUp(with event: NSEvent) {
        // 1. Finish Canvas Resize (Directional expansion / cropping commit)
        if let _ = activeResizeHandle, let preview = resizePreviewFrame {
            let expandLeft = canvasRect.minX - preview.minX
            let expandTop = canvasRect.minY - preview.minY
            let newSize = CGSize(width: preview.width, height: preview.height)
            let offset = CGPoint(x: expandLeft, y: expandTop)

            model.resizeCanvas(to: newSize, offset: offset, backgroundColor: secondaryColor)
            model.pushUndoState()

            activeResizeHandle = nil
            resizePreviewFrame = nil
            updateFrameSize()
            delegate?.canvasDidUpdateSize(model.size)
            needsDisplay = true
            return
        }

        // 2. Finish Marquee Selection
        if isSelectingMarquee {
            isSelectingMarquee = false
            let selRect = marqueeRect
            marqueeRect = .zero

            if selRect.width >= 4 && selRect.height >= 4 {
                if let cropped = cropImage(from: selRect) {
                    let selection = FloatingSelection(image: cropped, origin: selRect.origin, originalRect: selRect, isLifted: false)
                    self.floatingSelection = selection
                }
            }
            needsDisplay = true
            return
        }

        // 3. Finish Floating Selection Drag
        if let selection = floatingSelection {
            selection.activeHandle = nil
            needsDisplay = true
        }

        // 4. Finish Shape Drawing (Commit to Context)
        if isDrawing {
            switch currentTool {
            case .line:
                commitLine(from: startPoint, to: lastPoint)
            case .rectangle:
                if let rect = currentShapePreviewRect { commitRect(rect) }
            case .roundedRect:
                if let rect = currentShapePreviewRect { commitRoundedRect(rect) }
            case .oval:
                if let rect = currentShapePreviewRect { commitOval(rect) }
            case .pencil, .brush, .eraser:
                model.pushUndoState()
            default:
                break
            }
            isDrawing = false
            currentShapePreviewRect = nil
            needsDisplay = true
        }
    }

    // MARK: - Drawing Helpers
    private func drawLineSegment(from: CGPoint, to: CGPoint) {
        guard let ctx = model.context else { return }
        ctx.saveGState()
        
        let color = (currentTool == .eraser) ? secondaryColor : primaryColor
        let width = (currentTool == .pencil) ? 1.0 : ((currentTool == .eraser) ? strokeWidth * 2.5 : strokeWidth)

        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.beginPath()
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
        ctx.restoreGState()

        needsDisplay = true
    }

    private func commitLine(from: CGPoint, to: CGPoint) {
        guard let ctx = model.context else { return }
        ctx.saveGState()
        ctx.setStrokeColor(primaryColor.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.beginPath()
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
        ctx.restoreGState()

        model.pushUndoState()
    }

    private func commitRect(_ rect: CGRect) {
        guard let ctx = model.context else { return }
        ctx.saveGState()
        ctx.setStrokeColor(primaryColor.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.stroke(rect)
        ctx.restoreGState()

        model.pushUndoState()
    }

    private func commitRoundedRect(_ rect: CGRect) {
        guard let ctx = model.context else { return }
        ctx.saveGState()
        ctx.setStrokeColor(primaryColor.cgColor)
        ctx.setLineWidth(strokeWidth)
        let path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        model.pushUndoState()
    }

    private func commitOval(_ rect: CGRect) {
        guard let ctx = model.context else { return }
        ctx.saveGState()
        ctx.setStrokeColor(primaryColor.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.strokeEllipse(in: rect)
        ctx.restoreGState()

        model.pushUndoState()
    }

    private func pickColor(at point: CGPoint) {
        guard let data = model.context.data else { return }
        let bytesPerRow = model.context.bytesPerRow
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < model.context.width, y >= 0, y < model.context.height else { return }

        let ptr = data.bindMemory(to: UInt8.self, capacity: model.context.height * bytesPerRow)
        let offset = y * bytesPerRow + x * 4
        let r = CGFloat(ptr[offset]) / 255.0
        let g = CGFloat(ptr[offset + 1]) / 255.0
        let b = CGFloat(ptr[offset + 2]) / 255.0
        let a = CGFloat(ptr[offset + 3]) / 255.0

        let picked = NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        self.primaryColor = picked
        delegate?.canvasDidPickColor(picked)
        self.currentTool = .pencil
    }

    // MARK: - Inline Text Editor
    public func startInlineTextEditor(at point: CGPoint) {
        commitInlineText()

        let editor = InlineTextEditor(origin: point, canvasSize: model.size, initialColor: primaryColor)
        editor.frame = canvasRect
        editor.selectedFontSize = max(14, strokeWidth * 4)
        editor.delegate = self
        addSubview(editor)
        window?.makeFirstResponder(editor.textView)
        self.activeTextEditor = editor
    }

    public func commitInlineText() {
        activeTextEditor?.commit()
    }

    // MARK: - InlineTextEditorDelegate
    public func textEditorDidCommit(attributedString: NSAttributedString, at point: CGPoint) {
        guard let ctx = model.context else { return }

        // Draw into model.context using NSGraphicsContext flipped mode
        let gCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gCtx

        let availW = max(10, model.size.width - point.x)
        let availH = max(10, model.size.height - point.y)
        let boxWidth = activeTextEditor?.textView.frame.width ?? availW
        let drawWidth = max(10, min(boxWidth - 8, availW - 4))
        let drawRect = NSRect(x: point.x + 4, y: point.y + 4, width: drawWidth, height: availH - 4)
        attributedString.draw(in: drawRect)

        NSGraphicsContext.restoreGraphicsState()

        activeTextEditor = nil
        model.pushUndoState()
        needsDisplay = true
    }

    public func textEditorDidCancel() {
        activeTextEditor = nil
        needsDisplay = true
    }

    public func textEditorDidChangeColor(_ color: NSColor) {
        self.primaryColor = color
        delegate?.canvasDidPickColor(color)
    }

    public override func cancelOperation(_ sender: Any?) {
        commitInlineText()
    }

    // MARK: - Selection Manipulation & Clipboard
    public func cropImage(from rect: CGRect) -> NSImage? {
        guard let fullCG = model.currentCGImage() else { return nil }
        let integralRect = rect.integral
        let canvasBounds = CGRect(origin: .zero, size: model.size)
        let intersection = integralRect.intersection(canvasBounds)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return nil }

        guard let croppedCG = fullCG.cropping(to: intersection) else { return nil }
        let rep = NSBitmapImageRep(cgImage: croppedCG)
        let image = NSImage(size: intersection.size)
        image.addRepresentation(rep)
        return image
    }

    public func fillCanvasRect(_ rect: CGRect, with color: NSColor) {
        guard let ctx = model.context else { return }
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
        ctx.restoreGState()
    }

    public func selectAllCanvas() {
        commitFloatingSelection()
        let rect = CGRect(origin: .zero, size: model.size)
        if let cropped = cropImage(from: rect) {
            let sel = FloatingSelection(image: cropped, origin: .zero, originalRect: rect, isLifted: false)
            self.floatingSelection = sel
            self.currentTool = .select
            needsDisplay = true
        }
    }

    public func copySelection() {
        guard let selection = floatingSelection else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([selection.image])
    }

    public func cutSelection() {
        guard floatingSelection != nil else { return }
        copySelection()
        deleteSelection()
    }

    public func deleteSelection() {
        guard let selection = floatingSelection else { return }
        if !selection.isLifted {
            if let orig = selection.originalRect {
                fillCanvasRect(orig, with: secondaryColor)
            }
            model.pushUndoState()
        }
        self.floatingSelection = nil
        needsDisplay = true
    }

    public func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard let selection = floatingSelection else { return }
        if !selection.isLifted {
            if let orig = selection.originalRect {
                fillCanvasRect(orig, with: secondaryColor)
            }
            selection.isLifted = true
            model.pushUndoState()
        }
        selection.frame.origin.x += dx
        selection.frame.origin.y += dy
        needsDisplay = true
    }

    // MARK: - Key Handling
    public override var acceptsFirstResponder: Bool {
        return true
    }

    public override func keyDown(with event: NSEvent) {
        if activeTextEditor == nil {
            // Delete / Backspace (keyCode 51 or 117)
            if event.keyCode == 51 || event.keyCode == 117 {
                if floatingSelection != nil {
                    deleteSelection()
                    return
                }
            }

            // Return / Enter (keyCode 36) or Escape (keyCode 53)
            if event.keyCode == 36 || event.keyCode == 53 {
                if floatingSelection != nil {
                    commitFloatingSelection()
                    return
                }
            }

            // Arrow keys to nudge floating selection (1px or 10px with Shift)
            if floatingSelection != nil {
                let step: CGFloat = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
                switch event.keyCode {
                case 123: // Left
                    nudgeSelection(dx: -step, dy: 0)
                    return
                case 124: // Right
                    nudgeSelection(dx: step, dy: 0)
                    return
                case 125: // Down
                    nudgeSelection(dx: 0, dy: step)
                    return
                case 126: // Up
                    nudgeSelection(dx: 0, dy: -step)
                    return
                default:
                    break
                }
            }
        }

        super.keyDown(with: event)
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let editor = activeTextEditor {
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "b", "B":
                    editor.toggleBold()
                    return true
                case "i", "I":
                    editor.toggleItalic()
                    return true
                case "u", "U":
                    editor.toggleUnderline()
                    return true
                default:
                    break
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
