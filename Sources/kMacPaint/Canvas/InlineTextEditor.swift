import AppKit

public protocol InlineTextEditorDelegate: AnyObject {
    func textEditorDidCommit(attributedString: NSAttributedString, at point: CGPoint)
    func textEditorDidCancel()
    func textEditorDidChangeColor(_ color: NSColor)
}

public final class InlineTextEditor: NSView, NSTextViewDelegate {
    public weak var delegate: InlineTextEditorDelegate?

    public var textOrigin: CGPoint = .zero
    public var canvasBounds: CGSize = CGSize(width: 1024, height: 768)

    public var textColor: NSColor = .black {
        didSet {
            colorWell.color = textColor
            applyTextColor(textColor)
        }
    }

    // Formatting State
    public var selectedFontFamily: String = "Apple SD Gothic Neo" {
        didSet { applyFontFamily(selectedFontFamily) }
    }
    public var selectedFontSize: CGFloat = 16.0 {
        didSet { applyFontSize(selectedFontSize) }
    }
    public var isBold: Bool = false {
        didSet {
            boldButton.state = isBold ? .on : .off
            applyBold(isBold)
        }
    }
    public var isItalic: Bool = false {
        didSet {
            italicButton.state = isItalic ? .on : .off
            applyItalic(isItalic)
        }
    }
    public var isUnderline: Bool = false {
        didSet {
            underlineButton.state = isUnderline ? .on : .off
            applyUnderline(isUnderline)
        }
    }

    // Internal flag to avoid feedback loops when syncing UI from selection
    private var isUpdatingUIFromSelection = false

    // UI Subviews
    private let ribbonBar = NSView()
    private let fontPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sizePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let boldButton = NSButton()
    private let italicButton = NSButton()
    private let underlineButton = NSButton()
    private let colorWell = NSColorWell()
    private let fontPanelButton = NSButton()

    public let textView = InlineCustomTextView()
    private let dashedBorderLayer = CAShapeLayer()

    private let ribbonWidth: CGFloat = 300
    private let ribbonHeight: CGFloat = 28

    public init(origin: CGPoint, canvasSize: CGSize, initialColor: NSColor) {
        self.textOrigin = origin
        self.canvasBounds = canvasSize
        self.textColor = initialColor
        super.init(frame: NSRect(origin: .zero, size: canvasSize))

        setupRibbon()
        setupTextView()
        updateLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isFlipped: Bool { return true }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        let ribbonFrame = ribbonBar.frame
        let textFrame = textView.frame
        if ribbonFrame.contains(point) || textFrame.contains(point) {
            return super.hitTest(point)
        }
        return nil
    }

    private func setupRibbon() {
        ribbonBar.wantsLayer = true
        ribbonBar.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 0.98).cgColor
        ribbonBar.layer?.borderColor = NSColor(calibratedWhite: 0.78, alpha: 1.0).cgColor
        ribbonBar.layer?.borderWidth = 1.0
        ribbonBar.layer?.cornerRadius = 5.0
        ribbonBar.layer?.shadowColor = NSColor.black.cgColor
        ribbonBar.layer?.shadowOpacity = 0.15
        ribbonBar.layer?.shadowOffset = CGSize(width: 0, height: -2)
        ribbonBar.layer?.shadowRadius = 4.0

        // 1. Font PopUp
        let fonts = ["Apple SD Gothic Neo", "Helvetica", "Arial", "Times New Roman", "Courier New", "Georgia", "Menlo"]
        fontPopUp.addItems(withTitles: fonts)
        if fontPopUp.itemTitles.contains(selectedFontFamily) {
            fontPopUp.selectItem(withTitle: selectedFontFamily)
        }
        fontPopUp.target = self
        fontPopUp.action = #selector(fontChanged)
        fontPopUp.controlSize = .small
        fontPopUp.font = NSFont.systemFont(ofSize: 11)

        // 2. Size PopUp
        let sizes: [CGFloat] = [9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36, 48, 72]
        for s in sizes {
            sizePopUp.addItem(withTitle: "\(Int(s))")
        }
        sizePopUp.selectItem(withTitle: "\(Int(selectedFontSize))")
        sizePopUp.target = self
        sizePopUp.action = #selector(sizeChanged)
        sizePopUp.controlSize = .small
        sizePopUp.font = NSFont.systemFont(ofSize: 11)

        // 3. Bold Button
        setupStyleButton(boldButton, title: "B", action: #selector(toggleBold))
        boldButton.font = NSFont.boldSystemFont(ofSize: 11)

        // 4. Italic Button
        setupStyleButton(italicButton, title: "I", action: #selector(toggleItalic))
        italicButton.font = NSFont(name: "Georgia-Italic", size: 11) ?? NSFont.systemFont(ofSize: 11)

        // 5. Underline Button
        setupStyleButton(underlineButton, title: "U", action: #selector(toggleUnderline))
        underlineButton.font = NSFont.systemFont(ofSize: 11)

        // 6. Color Well
        colorWell.color = textColor
        colorWell.target = self
        colorWell.action = #selector(colorWellChanged(_:))
        colorWell.isBordered = true

        // 7. Font Panel Button
        setupStyleButton(fontPanelButton, title: "서체…", action: #selector(openFontPanel))
        fontPanelButton.font = NSFont.systemFont(ofSize: 10)

        ribbonBar.addSubview(fontPopUp)
        ribbonBar.addSubview(sizePopUp)
        ribbonBar.addSubview(boldButton)
        ribbonBar.addSubview(italicButton)
        ribbonBar.addSubview(underlineButton)
        ribbonBar.addSubview(colorWell)
        ribbonBar.addSubview(fontPanelButton)

        addSubview(ribbonBar)
    }

    private func setupStyleButton(_ btn: NSButton, title: String, action: Selector) {
        btn.title = title
        btn.setButtonType(.pushOnPushOff)
        btn.bezelStyle = .roundRect
        btn.target = self
        btn.action = action
        btn.controlSize = .small
    }

    private func setupTextView() {
        textView.delegate = self
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.backgroundColor = NSColor.white.withAlphaComponent(0.85)
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 4, height: 4)

        wantsLayer = true
        dashedBorderLayer.strokeColor = NSColor.systemBlue.cgColor
        dashedBorderLayer.fillColor = nil
        dashedBorderLayer.lineWidth = 1.2
        dashedBorderLayer.lineDashPattern = [4, 3]
        layer?.addSublayer(dashedBorderLayer)

        addSubview(textView)

        // Initial default typing attributes
        let font = currentFont()
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .underlineStyle: 0
        ]
    }

    public func updateLayout() {
        let font = currentFont()
        let text = textView.string
        
        let sampleSize = (" " as NSString).size(withAttributes: [.font: font])
        let lineHeight = max(20, sampleSize.height + 6)

        var textW: CGFloat = 80
        var textH: CGFloat = lineHeight

        if !text.isEmpty {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
            let lines = text.components(separatedBy: "\n")
            var maxLineWidth: CGFloat = 0
            for line in lines {
                let w = (line as NSString).size(withAttributes: attrs).width
                if w > maxLineWidth { maxLineWidth = w }
            }
            textW = max(80, maxLineWidth + 16)
            textH = max(lineHeight, CGFloat(lines.count) * lineHeight + 4)
        }

        let maxAvailableW = max(80, canvasBounds.width - textOrigin.x - 8)
        textW = min(textW, maxAvailableW)

        let textFrame = NSRect(x: textOrigin.x, y: textOrigin.y, width: textW, height: textH)
        textView.frame = textFrame
        textView.textContainer?.containerSize = NSSize(width: textW - 8, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        dashedBorderLayer.path = CGPath(rect: textFrame, transform: nil)

        // Smart ribbon placement
        let ribbonY: CGFloat
        if textOrigin.y < ribbonHeight + 8 {
            ribbonY = textOrigin.y + textH + 6
        } else {
            ribbonY = textOrigin.y - ribbonHeight - 6
        }

        var ribbonX = textOrigin.x
        if ribbonX + ribbonWidth > canvasBounds.width - 8 {
            ribbonX = max(8, canvasBounds.width - ribbonWidth - 8)
        }
        if ribbonX < 8 {
            ribbonX = 8
        }

        ribbonBar.frame = NSRect(x: ribbonX, y: ribbonY, width: ribbonWidth, height: ribbonHeight)

        var rx: CGFloat = 4
        fontPopUp.frame = NSRect(x: rx, y: 3, width: 122, height: 22); rx += 126
        sizePopUp.frame = NSRect(x: rx, y: 3, width: 44, height: 22); rx += 48
        boldButton.frame = NSRect(x: rx, y: 3, width: 20, height: 22); rx += 22
        italicButton.frame = NSRect(x: rx, y: 3, width: 20, height: 22); rx += 22
        underlineButton.frame = NSRect(x: rx, y: 3, width: 20, height: 22); rx += 22
        colorWell.frame = NSRect(x: rx, y: 3, width: 22, height: 22); rx += 25
        fontPanelButton.frame = NSRect(x: rx, y: 3, width: 34, height: 22)
    }

    public func currentFont() -> NSFont {
        let baseFont = NSFont(name: selectedFontFamily, size: selectedFontSize) ?? NSFont.systemFont(ofSize: selectedFontSize)
        let fontManager = NSFontManager.shared
        var font = baseFont
        if isBold {
            font = fontManager.convert(font, toHaveTrait: .boldFontMask)
        }
        if isItalic {
            font = fontManager.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }

    // MARK: - Rich Text Formatting (Targeted to Selection or Whole/Typing)
    private var targetRange: NSRange {
        let sel = textView.selectedRange()
        if sel.length > 0 {
            return sel
        }
        // If nothing is selected, check if there's any text; if so, apply to whole or typing
        return NSRange(location: 0, length: 0)
    }

    public func applyTextColor(_ color: NSColor) {
        guard !isUpdatingUIFromSelection else { return }
        let sel = textView.selectedRange()
        if sel.length > 0, let textStorage = textView.textStorage {
            textStorage.addAttribute(.foregroundColor, value: color, range: sel)
        } else {
            textView.typingAttributes[.foregroundColor] = color
            // If whole text should be colored when nothing selected
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: textStorage.length))
            }
        }
    }

    public func applyBold(_ bold: Bool) {
        guard !isUpdatingUIFromSelection else { return }
        let sel = textView.selectedRange()
        let fm = NSFontManager.shared
        if sel.length > 0, let textStorage = textView.textStorage {
            textStorage.enumerateAttribute(.font, in: sel, options: []) { (value, subRange, _) in
                let current = (value as? NSFont) ?? self.currentFont()
                let newFont = bold ? fm.convert(current, toHaveTrait: .boldFontMask) : fm.convert(current, toNotHaveTrait: .boldFontMask)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        } else {
            let current = (textView.typingAttributes[.font] as? NSFont) ?? currentFont()
            let newFont = bold ? fm.convert(current, toHaveTrait: .boldFontMask) : fm.convert(current, toNotHaveTrait: .boldFontMask)
            textView.typingAttributes[.font] = newFont
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length), options: []) { (value, subRange, _) in
                    let f = (value as? NSFont) ?? self.currentFont()
                    let nf = bold ? fm.convert(f, toHaveTrait: .boldFontMask) : fm.convert(f, toNotHaveTrait: .boldFontMask)
                    textStorage.addAttribute(.font, value: nf, range: subRange)
                }
            }
        }
        updateLayout()
    }

    public func applyItalic(_ italic: Bool) {
        guard !isUpdatingUIFromSelection else { return }
        let sel = textView.selectedRange()
        let fm = NSFontManager.shared
        if sel.length > 0, let textStorage = textView.textStorage {
            textStorage.enumerateAttribute(.font, in: sel, options: []) { (value, subRange, _) in
                let current = (value as? NSFont) ?? self.currentFont()
                let newFont = italic ? fm.convert(current, toHaveTrait: .italicFontMask) : fm.convert(current, toNotHaveTrait: .italicFontMask)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        } else {
            let current = (textView.typingAttributes[.font] as? NSFont) ?? currentFont()
            let newFont = italic ? fm.convert(current, toHaveTrait: .italicFontMask) : fm.convert(current, toNotHaveTrait: .italicFontMask)
            textView.typingAttributes[.font] = newFont
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length), options: []) { (value, subRange, _) in
                    let f = (value as? NSFont) ?? self.currentFont()
                    let nf = italic ? fm.convert(f, toHaveTrait: .italicFontMask) : fm.convert(f, toNotHaveTrait: .italicFontMask)
                    textStorage.addAttribute(.font, value: nf, range: subRange)
                }
            }
        }
        updateLayout()
    }

    public func applyUnderline(_ underline: Bool) {
        guard !isUpdatingUIFromSelection else { return }
        let sel = textView.selectedRange()
        let val = underline ? NSUnderlineStyle.single.rawValue : 0
        if sel.length > 0, let textStorage = textView.textStorage {
            textStorage.addAttribute(.underlineStyle, value: val, range: sel)
        } else {
            textView.typingAttributes[.underlineStyle] = val
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.addAttribute(.underlineStyle, value: val, range: NSRange(location: 0, length: textStorage.length))
            }
        }
    }

    public func applyFontFamily(_ family: String) {
        guard !isUpdatingUIFromSelection else { return }
        let sel = textView.selectedRange()
        let fm = NSFontManager.shared
        if sel.length > 0, let textStorage = textView.textStorage {
            textStorage.enumerateAttribute(.font, in: sel, options: []) { (value, subRange, _) in
                let oldFont = (value as? NSFont) ?? self.currentFont()
                let traits = fm.traits(of: oldFont)
                var newFont = NSFont(name: family, size: oldFont.pointSize) ?? NSFont.systemFont(ofSize: oldFont.pointSize)
                if traits.contains(.boldFontMask) {
                    newFont = fm.convert(newFont, toHaveTrait: .boldFontMask)
                }
                if traits.contains(.italicFontMask) {
                    newFont = fm.convert(newFont, toHaveTrait: .italicFontMask)
                }
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        } else {
            let current = currentFont()
            textView.typingAttributes[.font] = current
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length), options: []) { (value, subRange, _) in
                    let oldFont = (value as? NSFont) ?? current
                    let traits = fm.traits(of: oldFont)
                    var newFont = NSFont(name: family, size: oldFont.pointSize) ?? NSFont.systemFont(ofSize: oldFont.pointSize)
                    if traits.contains(.boldFontMask) { newFont = fm.convert(newFont, toHaveTrait: .boldFontMask) }
                    if traits.contains(.italicFontMask) { newFont = fm.convert(newFont, toHaveTrait: .italicFontMask) }
                    textStorage.addAttribute(.font, value: newFont, range: subRange)
                }
            }
        }
        updateLayout()
    }

    public func applyFontSize(_ size: CGFloat) {
        guard !isUpdatingUIFromSelection else { return }
        let sel = textView.selectedRange()
        let fm = NSFontManager.shared
        if sel.length > 0, let textStorage = textView.textStorage {
            textStorage.enumerateAttribute(.font, in: sel, options: []) { (value, subRange, _) in
                let oldFont = (value as? NSFont) ?? self.currentFont()
                let traits = fm.traits(of: oldFont)
                let family = oldFont.familyName ?? self.selectedFontFamily
                var newFont = NSFont(name: family, size: size) ?? NSFont.systemFont(ofSize: size)
                if traits.contains(.boldFontMask) {
                    newFont = fm.convert(newFont, toHaveTrait: .boldFontMask)
                }
                if traits.contains(.italicFontMask) {
                    newFont = fm.convert(newFont, toHaveTrait: .italicFontMask)
                }
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        } else {
            let current = currentFont()
            textView.typingAttributes[.font] = current
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length), options: []) { (value, subRange, _) in
                    let oldFont = (value as? NSFont) ?? current
                    let traits = fm.traits(of: oldFont)
                    let family = oldFont.familyName ?? self.selectedFontFamily
                    var newFont = NSFont(name: family, size: size) ?? NSFont.systemFont(ofSize: size)
                    if traits.contains(.boldFontMask) { newFont = fm.convert(newFont, toHaveTrait: .boldFontMask) }
                    if traits.contains(.italicFontMask) { newFont = fm.convert(newFont, toHaveTrait: .italicFontMask) }
                    textStorage.addAttribute(.font, value: newFont, range: subRange)
                }
            }
        }
        updateLayout()
    }

    // MARK: - NSTextViewDelegate
    public func textDidChange(_ notification: Notification) {
        updateLayout()
    }

    public func textViewDidChangeSelection(_ notification: Notification) {
        // Sync toolbar UI to reflect formatting of currently selected text or cursor position
        guard let textStorage = textView.textStorage, textStorage.length > 0 else { return }
        let sel = textView.selectedRange()
        let inspectIdx = sel.length > 0 ? sel.location : max(0, min(sel.location, textStorage.length - 1))
        guard inspectIdx < textStorage.length else { return }

        let attrs = textStorage.attributes(at: inspectIdx, effectiveRange: nil)
        isUpdatingUIFromSelection = true
        defer { isUpdatingUIFromSelection = false }

        if let font = attrs[.font] as? NSFont {
            let fm = NSFontManager.shared
            let traits = fm.traits(of: font)
            let family = font.familyName ?? font.fontName
            let size = font.pointSize

            selectedFontFamily = family
            selectedFontSize = size
            isBold = traits.contains(.boldFontMask)
            isItalic = traits.contains(.italicFontMask)

            if fontPopUp.itemTitles.contains(family) {
                fontPopUp.selectItem(withTitle: family)
            }
            sizePopUp.selectItem(withTitle: "\(Int(size))")
            boldButton.state = isBold ? .on : .off
            italicButton.state = isItalic ? .on : .off
        }

        if let color = attrs[.foregroundColor] as? NSColor {
            textColor = color
            colorWell.color = color
        }

        if let u = attrs[.underlineStyle] as? Int {
            isUnderline = (u != 0)
            underlineButton.state = isUnderline ? .on : .off
        } else {
            isUnderline = false
            underlineButton.state = .off
        }
    }

    // MARK: - Actions
    @objc private func fontChanged(_ sender: NSPopUpButton) {
        if let title = sender.titleOfSelectedItem {
            selectedFontFamily = title
        }
    }

    @objc private func sizeChanged(_ sender: NSPopUpButton) {
        if let title = sender.titleOfSelectedItem, let s = Double(title) {
            selectedFontSize = CGFloat(s)
        }
    }

    @objc public func toggleBold() {
        isBold.toggle()
    }

    @objc public func toggleItalic() {
        isItalic.toggle()
    }

    @objc public func toggleUnderline() {
        isUnderline.toggle()
    }

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        self.textColor = sender.color
        delegate?.textEditorDidChangeColor(sender.color)
    }

    @objc private func openFontPanel() {
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.action = #selector(changeFontFromPanel(_:))
        fontManager.orderFrontFontPanel(nil)
    }

    @objc private func changeFontFromPanel(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        let newFont = fontManager.convert(currentFont())
        selectedFontFamily = newFont.familyName ?? newFont.fontName
        selectedFontSize = newFont.pointSize
        isBold = fontManager.traits(of: newFont).contains(.boldFontMask)
        isItalic = fontManager.traits(of: newFont).contains(.italicFontMask)

        if fontPopUp.itemTitles.contains(selectedFontFamily) {
            fontPopUp.selectItem(withTitle: selectedFontFamily)
        }
        sizePopUp.selectItem(withTitle: "\(Int(selectedFontSize))")
        updateLayout()
    }

    // MARK: - Commit & Cancel
    public func commit() {
        let attrString = textView.attributedString()
        if attrString.length > 0 && !attrString.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            delegate?.textEditorDidCommit(attributedString: attrString, at: textOrigin)
        } else {
            delegate?.textEditorDidCancel()
        }
        removeFromSuperview()
    }

    public func cancel() {
        delegate?.textEditorDidCancel()
        removeFromSuperview()
    }

    public override func cancelOperation(_ sender: Any?) {
        commit()
    }
}

// Custom NSTextView that handles Command+A and Escape
public final class InlineCustomTextView: NSTextView {
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "a" || event.charactersIgnoringModifiers == "A" {
                self.selectAll(nil)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
