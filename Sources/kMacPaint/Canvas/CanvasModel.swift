import AppKit

public final class CanvasModel {
    public private(set) var size: CGSize
    public private(set) var context: CGContext!
    
    // Undo / Redo history
    private var undoStack: [CGImage] = []
    private var redoStack: [CGImage] = []
    public static let defaultMaxUndoSteps: Int = 35

    /// Dynamically scales undo steps based on canvas pixel count to prevent excessive RAM pressure on 4K+ images
    public var maxUndoSteps: Int {
        let pixels = size.width * size.height
        if pixels >= 8_000_000 { // 4K or above (~33MB per snapshot)
            return 12
        } else if pixels >= 3_000_000 { // QHD / 3MP (~12MB per snapshot)
            return 20
        } else {
            return Self.defaultMaxUndoSteps // Standard (~3MB per snapshot) -> 35
        }
    }

    // Document Dirty State Tracking
    public private(set) var isDirty: Bool = false {
        didSet {
            onDirtyChange?(isDirty)
        }
    }
    public var onDirtyChange: ((Bool) -> Void)?
    private var savedSnapshot: CGImage?

    public var onChange: (() -> Void)?

    public init(size: CGSize = CGSize(width: 1024, height: 768), backgroundColor: NSColor = .white) {
        self.size = size
        self.context = Self.createBitmapContext(size: size)
        clear(color: backgroundColor)
        pushUndoState()
        markClean()
    }

    public static func createBitmapContext(size: CGSize) -> CGContext? {
        let width = Int(max(1, size.width))
        let height = Int(max(1, size.height))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        // Setup flipped coordinates internally (y=0 at top)
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1.0, y: -1.0)
        return ctx
    }

    public func clear(color: NSColor = .white) {
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.restoreGState()
        onChange?()
    }

    public func markClean() {
        self.savedSnapshot = undoStack.last
        self.isDirty = false
    }

    private func checkDirtyState() {
        if let current = undoStack.last, let saved = savedSnapshot {
            self.isDirty = (current !== saved)
        } else {
            self.isDirty = true
        }
    }

    public func pushUndoState() {
        if let snapshot = currentCGImage() {
            undoStack.append(snapshot)
            let limit = maxUndoSteps
            while undoStack.count > limit {
                undoStack.removeFirst()
            }
            redoStack.removeAll()
            checkDirtyState()
        }
    }

    public var canUndo: Bool {
        return undoStack.count > 1
    }

    public var canRedo: Bool {
        return !redoStack.isEmpty
    }

    public func undo() {
        guard canUndo else { return }
        let current = undoStack.removeLast()
        redoStack.append(current)

        if let previous = undoStack.last {
            restoreSnapshot(previous)
        }
        checkDirtyState()
        onChange?()
    }

    public func redo() {
        guard canRedo else { return }
        let next = redoStack.removeLast()
        undoStack.append(next)
        restoreSnapshot(next)
        checkDirtyState()
        onChange?()
    }

    private func restoreSnapshot(_ image: CGImage) {
        let imgSize = CGSize(width: image.width, height: image.height)
        if self.size != imgSize {
            self.size = imgSize
            self.context = Self.createBitmapContext(size: imgSize)
        }
        context.saveGState()
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        // Draw flipped because context is flipped
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(origin: .zero, size: size))
        context.restoreGState()
    }

    public func currentCGImage() -> CGImage? {
        return context.makeImage()
    }

    /// Resize Canvas - Supports directional expansion (Left, Right, Top, Bottom):
    /// - `newSize`: The target canvas dimensions.
    /// - `offset`: Placement offset of the existing drawing within the new canvas (e.g. for expanding left/top).
    /// - `backgroundColor`: Color to fill newly exposed canvas areas (usually Color 2 / secondaryColor).
    public func resizeCanvas(to newSize: CGSize, offset: CGPoint = .zero, backgroundColor: NSColor = .white) {
        guard let oldImage = currentCGImage() else { return }
        
        let validWidth = max(10, newSize.width)
        let validHeight = max(10, newSize.height)
        let newValidSize = CGSize(width: validWidth, height: validHeight)

        guard let newContext = Self.createBitmapContext(size: newValidSize) else { return }

        // 1. Fill new canvas with background color
        newContext.saveGState()
        newContext.setFillColor(backgroundColor.cgColor)
        newContext.fill(CGRect(origin: .zero, size: newValidSize))
        newContext.restoreGState()

        // 2. Draw existing image at specified offset (top-down coordinates)
        newContext.saveGState()
        newContext.translateBy(x: offset.x, y: offset.y + CGFloat(oldImage.height))
        newContext.scaleBy(x: 1.0, y: -1.0)
        newContext.draw(oldImage, in: CGRect(x: 0, y: 0, width: oldImage.width, height: oldImage.height))
        newContext.restoreGState()

        self.size = newValidSize
        self.context = newContext
        onChange?()
    }

    public func load(from image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let newSize = CGSize(width: cg.width, height: cg.height)
        guard let newContext = Self.createBitmapContext(size: newSize) else { return }

        newContext.saveGState()
        newContext.setFillColor(NSColor.white.cgColor)
        newContext.fill(CGRect(origin: .zero, size: newSize))
        newContext.translateBy(x: 0, y: newSize.height)
        newContext.scaleBy(x: 1.0, y: -1.0)
        newContext.draw(cg, in: CGRect(origin: .zero, size: newSize))
        newContext.restoreGState()

        self.size = newSize
        self.context = newContext
        pushUndoState()
        markClean()
        onChange?()
    }

    public func exportData(format: NSBitmapImageRep.FileType) -> Data? {
        guard let cg = currentCGImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = size
        return rep.representation(using: format, properties: [:])
    }
}
