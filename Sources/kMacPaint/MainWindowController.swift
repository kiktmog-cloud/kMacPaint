import AppKit

public final class MainWindowController: NSWindowController, NSWindowDelegate, ToolbarViewDelegate, CanvasViewDelegate {
    public let model: CanvasModel
    public let canvasView: CanvasView
    public let toolbarView: ToolbarView
    public let scrollView: NSScrollView
    public let statusContainer: NSView
    public let statusBar: NSTextField
    public let zoomSlider: NSSlider
    public let zoomLabel: NSTextField
    public let zoomMinusButton: NSButton
    public let zoomPlusButton: NSButton

    // Document Metadata & State
    public var documentTitle: String = "제목 없음"
    public var documentURL: URL? = nil

    public init() {
        self.model = CanvasModel(size: CGSize(width: 1024, height: 768))
        self.canvasView = CanvasView(model: model)
        self.toolbarView = ToolbarView()
        self.scrollView = NSScrollView()
        self.statusContainer = NSView()
        self.statusBar = NSTextField(labelWithString: " 준비 완료  |  캔버스: 1024 x 768px")
        
        self.zoomSlider = NSSlider(value: 1.0, minValue: 0.25, maxValue: 8.0, target: nil, action: nil)
        self.zoomLabel = NSTextField(labelWithString: "100%")
        self.zoomMinusButton = NSButton(title: "−", target: nil, action: nil)
        self.zoomPlusButton = NSButton(title: "+", target: nil, action: nil)

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1100, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "그림판 (kMacPaint - Windows 11 mspaint Edition)"
        window.minSize = NSSize(width: 800, height: 600)
        window.center()

        super.init(window: window)
        window.delegate = self

        setupLayout()
        setupZoomControls()
        
        toolbarView.delegate = self
        canvasView.delegate = self

        model.onDirtyChange = { [weak self] _ in
            self?.updateWindowTitle()
        }
        updateWindowTitle()

        DispatchQueue.main.async { [weak self] in
            self?.centerCanvasInScrollView()
        }

        // Observe magnification changes from trackpad gestures or shortcuts
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidMagnify),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidMagnify),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        guard let contentView = window?.contentView else { return }

        // Setup ScrollView with native magnification (zoom) support
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 8.0
        scrollView.magnification = 1.0
        // Windows Paint signature neutral workspace gray
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.88, alpha: 1.0)
        scrollView.documentView = canvasView

        // Setup Status Bar Container
        statusContainer.wantsLayer = true
        statusContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1.0).cgColor

        statusBar.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        statusBar.textColor = NSColor.secondaryLabelColor
        statusBar.backgroundColor = .clear
        statusBar.isBezeled = false
        statusBar.isEditable = false

        // Zoom UI
        zoomMinusButton.bezelStyle = .inline
        zoomMinusButton.isBordered = false
        zoomMinusButton.target = self
        zoomMinusButton.action = #selector(zoomMinusClicked)
        zoomMinusButton.font = NSFont.boldSystemFont(ofSize: 13)

        zoomPlusButton.bezelStyle = .inline
        zoomPlusButton.isBordered = false
        zoomPlusButton.target = self
        zoomPlusButton.action = #selector(zoomPlusClicked)
        zoomPlusButton.font = NSFont.boldSystemFont(ofSize: 13)

        zoomSlider.target = self
        zoomSlider.action = #selector(zoomSliderChanged)

        zoomLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        zoomLabel.textColor = NSColor.secondaryLabelColor
        zoomLabel.alignment = .right
        zoomLabel.isBezeled = false
        zoomLabel.isEditable = false
        zoomLabel.backgroundColor = .clear

        statusContainer.addSubview(statusBar)
        statusContainer.addSubview(zoomMinusButton)
        statusContainer.addSubview(zoomSlider)
        statusContainer.addSubview(zoomPlusButton)
        statusContainer.addSubview(zoomLabel)

        contentView.addSubview(toolbarView)
        contentView.addSubview(scrollView)
        contentView.addSubview(statusContainer)

        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        zoomMinusButton.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomPlusButton.translatesAutoresizingMaskIntoConstraints = false
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toolbarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 72),

            scrollView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusContainer.topAnchor),

            statusContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusContainer.heightAnchor.constraint(equalToConstant: 24),

            statusBar.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 8),
            statusBar.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            statusBar.trailingAnchor.constraint(lessThanOrEqualTo: zoomMinusButton.leadingAnchor, constant: -8),

            zoomMinusButton.trailingAnchor.constraint(equalTo: zoomSlider.leadingAnchor, constant: -4),
            zoomMinusButton.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            zoomMinusButton.widthAnchor.constraint(equalToConstant: 18),

            zoomSlider.trailingAnchor.constraint(equalTo: zoomPlusButton.leadingAnchor, constant: -4),
            zoomSlider.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            zoomSlider.widthAnchor.constraint(equalToConstant: 110),

            zoomPlusButton.trailingAnchor.constraint(equalTo: zoomLabel.leadingAnchor, constant: -6),
            zoomPlusButton.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            zoomPlusButton.widthAnchor.constraint(equalToConstant: 18),

            zoomLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -12),
            zoomLabel.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            zoomLabel.widthAnchor.constraint(equalToConstant: 45)
        ])
    }

    private func setupZoomControls() {
        updateZoomUI()
    }

    // MARK: - Zoom Actions
    @objc public func zoomIn() {
        let newMag = min(scrollView.magnification * 1.25, scrollView.maxMagnification)
        scrollView.setMagnification(newMag, centeredAt: canvasView.visibleRect.origin)
        updateZoomUI()
    }

    @objc public func zoomOut() {
        let newMag = max(scrollView.magnification / 1.25, scrollView.minMagnification)
        scrollView.setMagnification(newMag, centeredAt: canvasView.visibleRect.origin)
        updateZoomUI()
    }

    @objc public func resetZoom() {
        scrollView.setMagnification(1.0, centeredAt: canvasView.visibleRect.origin)
        updateZoomUI()
    }

    @objc private func zoomMinusClicked() {
        zoomOut()
    }

    @objc private func zoomPlusClicked() {
        zoomIn()
    }

    @objc private func zoomSliderChanged() {
        let val = zoomSlider.doubleValue
        scrollView.setMagnification(CGFloat(val), centeredAt: canvasView.visibleRect.origin)
        updateZoomUI()
    }

    @objc private func scrollViewDidMagnify() {
        updateZoomUI()
    }

    public func updateZoomUI() {
        let percent = Int(round(scrollView.magnification * 100))
        zoomLabel.stringValue = "\(percent)%"
        zoomSlider.doubleValue = Double(scrollView.magnification)
    }

    // MARK: - ToolbarViewDelegate
    public func toolbarDidSelectTool(_ tool: ToolType) {
        canvasView.currentTool = tool
    }

    public func toolbarDidSelectStrokeWidth(_ width: CGFloat) {
        canvasView.strokeWidth = width
    }

    public func toolbarDidSelectColor(_ color: NSColor, forSlot slot: ColorSlot) {
        if slot == .primary {
            canvasView.primaryColor = color
        } else {
            canvasView.secondaryColor = color
        }
    }

    public func toolbarDidTriggerPaste() {
        pasteFromClipboard()
    }

    public func toolbarDidTriggerUndo() {
        undo()
    }

    public func toolbarDidTriggerRedo() {
        redo()
    }

    // MARK: - CanvasViewDelegate
    public func canvasDidUpdateSize(_ size: CGSize) {
        statusBar.stringValue = " 캔버스: \(Int(size.width)) x \(Int(size.height))px"
    }

    public func canvasDidUpdateCursorPosition(_ point: CGPoint) {
        let x = Int(point.x)
        let y = Int(point.y)
        statusBar.stringValue = " 위치: \(x), \(y)px  |  캔버스: \(Int(model.size.width)) x \(Int(model.size.height))px"
    }

    public func canvasDidPickColor(_ color: NSColor) {
        toolbarView.paletteView.primaryColor = color
        toolbarView.paletteView.needsDisplay = true
    }

    public func canvasDidChangeTool(_ tool: ToolType) {
        toolbarView.selectToolButton(tool)
    }

    // MARK: - Clipboard & Selection Actions
    public func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let image = NSImage(pasteboard: pasteboard) {
            canvasView.pasteImage(image)
        } else {
            let alert = NSAlert()
            alert.messageText = "붙여넣을 이미지가 없습니다"
            alert.informativeText = "클립보드에 복사된 이미지가 없습니다. 이미지를 복사한 후 다시 시도해 주세요."
            alert.runModal()
        }
    }

    public func copySelection() {
        if let editor = canvasView.activeTextEditor {
            editor.textView.copy(nil)
            return
        }
        canvasView.copySelection()
    }

    public func cutSelection() {
        if let editor = canvasView.activeTextEditor {
            editor.textView.cut(nil)
            return
        }
        canvasView.cutSelection()
    }

    public func deleteSelection() {
        if let editor = canvasView.activeTextEditor {
            editor.textView.delete(nil)
            return
        }
        canvasView.deleteSelection()
    }

    public func selectAll() {
        if let editor = canvasView.activeTextEditor {
            editor.textView.selectAll(nil)
            return
        }
        canvasView.selectAllCanvas()
    }

    // MARK: - Undo / Redo
    public func undo() {
        model.undo()
    }

    public func redo() {
        model.redo()
    }

    // MARK: - Window Title & Dirty Management
    public func updateWindowTitle() {
        let dirtyIndicator = model.isDirty ? " •" : ""
        window?.title = "\(documentTitle)\(dirtyIndicator) - 그림판 (kMacPaint)"
        window?.isDocumentEdited = model.isDirty
        window?.representedURL = documentURL
    }

    // MARK: - Window Delegate
    public func windowDidResize(_ notification: Notification) {
        canvasView.updateFrameSize()
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        return promptSaveIfModified()
    }

    public func windowWillClose(_ notification: Notification) {
        // Reset state so subsequent re-openings start clean
        model.clear(color: .white)
        model.markClean()
        documentURL = nil
        documentTitle = "제목 없음"
        updateWindowTitle()
    }

    /// Checks if there are unsaved changes and prompts the user to save.
    /// Returns true if safe to proceed (saved, discarded, or wasn't modified).
    /// Returns false if user cancelled.
    public func promptSaveIfModified() -> Bool {
        guard model.isDirty else { return true }

        let alert = NSAlert()
        alert.messageText = "'\(documentTitle)'의 변경사항을 저장하시겠습니까?"
        alert.informativeText = "저장하지 않으면 변경사항이 손실됩니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "저장 안 함")
        alert.addButton(withTitle: "취소")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn: // 저장
            return saveDocument()
        case .alertSecondButtonReturn: // 저장 안 함
            return true
        default: // 취소
            return false
        }
    }

    public func centerCanvasInScrollView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.canvasView.updateFrameSize()
            let docSize = self.canvasView.frame.size
            let clipSize = self.scrollView.contentView.bounds.size
            let targetX = max(0, (docSize.width - clipSize.width) / 2.0)
            let targetY = max(0, (docSize.height - clipSize.height) / 2.0)
            self.scrollView.contentView.scroll(to: NSPoint(x: targetX, y: targetY))
            self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
        }
    }

    // MARK: - File Operations
    public func newDocument() {
        guard promptSaveIfModified() else { return }
        model.clear(color: .white)
        model.markClean()
        documentURL = nil
        documentTitle = "제목 없음"
        updateWindowTitle()
        centerCanvasInScrollView()
    }

    public func openDocument() {
        guard promptSaveIfModified() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let img = NSImage(contentsOf: url) {
                model.load(from: img)
                documentURL = url
                documentTitle = url.deletingPathExtension().lastPathComponent
                model.markClean()
                updateWindowTitle()
                centerCanvasInScrollView()
            }
        }
    }

    public func insertImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "이미지 삽입 (캔버스 위에 얹기)"

        if panel.runModal() == .OK, let url = panel.url {
            if let img = NSImage(contentsOf: url) {
                canvasView.pasteImage(img)
            }
        }
    }

    @discardableResult
    public func saveDocument() -> Bool {
        if let url = documentURL {
            let format: NSBitmapImageRep.FileType = (url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg") ? .jpeg : .png
            if let data = model.exportData(format: format) {
                do {
                    try data.write(to: url)
                    model.markClean()
                    updateWindowTitle()
                    return true
                } catch {
                    // Fallback to Save Panel
                }
            }
        }
        return saveDocumentAs()
    }

    @discardableResult
    public func saveDocumentAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canCreateDirectories = true
        let defaultName = documentURL?.lastPathComponent ?? "\(documentTitle).png"
        panel.nameFieldStringValue = (defaultName.hasSuffix(".png") || defaultName.hasSuffix(".jpg") || defaultName.hasSuffix(".jpeg")) ? defaultName : "\(defaultName).png"

        if panel.runModal() == .OK, let url = panel.url {
            let format: NSBitmapImageRep.FileType = (url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg") ? .jpeg : .png
            if let data = model.exportData(format: format) {
                do {
                    try data.write(to: url)
                    documentURL = url
                    documentTitle = url.deletingPathExtension().lastPathComponent
                    model.markClean()
                    updateWindowTitle()
                    return true
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "파일을 저장하지 못했습니다"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                    return false
                }
            }
        }
        return false // Cancelled or failed
    }

    // MARK: - Canvas Size Dialog
    public func showCanvasSizeDialog() {
        let alert = NSAlert()
        alert.messageText = "캔버스 크기 및 여백 확장"
        alert.informativeText = "현재 캔버스 크기: \(Int(model.size.width)) x \(Int(model.size.height))px\n원하는 방향의 여백(px)을 입력하면 해당 방향으로 캔버스가 확장됩니다."
        alert.addButton(withTitle: "확장 적용")
        alert.addButton(withTitle: "취소")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 130))

        // Top margin
        let topLabel = NSTextField(labelWithString: "상단(Top) 여백:")
        topLabel.frame = NSRect(x: 10, y: 95, width: 110, height: 20)
        let topField = NSTextField(frame: NSRect(x: 130, y: 95, width: 90, height: 22))
        topField.stringValue = "0"
        let topPx = NSTextField(labelWithString: "px")
        topPx.frame = NSRect(x: 225, y: 95, width: 30, height: 20)

        // Bottom margin
        let bottomLabel = NSTextField(labelWithString: "하단(Bottom) 여백:")
        bottomLabel.frame = NSRect(x: 10, y: 65, width: 110, height: 20)
        let bottomField = NSTextField(frame: NSRect(x: 130, y: 65, width: 90, height: 22))
        bottomField.stringValue = "0"
        let bottomPx = NSTextField(labelWithString: "px")
        bottomPx.frame = NSRect(x: 225, y: 65, width: 30, height: 20)

        // Left margin
        let leftLabel = NSTextField(labelWithString: "좌측(Left) 여백:")
        leftLabel.frame = NSRect(x: 10, y: 35, width: 110, height: 20)
        let leftField = NSTextField(frame: NSRect(x: 130, y: 35, width: 90, height: 22))
        leftField.stringValue = "0"
        let leftPx = NSTextField(labelWithString: "px")
        leftPx.frame = NSRect(x: 225, y: 35, width: 30, height: 20)

        // Right margin
        let rightLabel = NSTextField(labelWithString: "우측(Right) 여백:")
        rightLabel.frame = NSRect(x: 10, y: 5, width: 110, height: 20)
        let rightField = NSTextField(frame: NSRect(x: 130, y: 5, width: 90, height: 22))
        rightField.stringValue = "0"
        let rightPx = NSTextField(labelWithString: "px")
        rightPx.frame = NSRect(x: 225, y: 5, width: 30, height: 20)

        container.addSubview(topLabel)
        container.addSubview(topField)
        container.addSubview(topPx)
        container.addSubview(bottomLabel)
        container.addSubview(bottomField)
        container.addSubview(bottomPx)
        container.addSubview(leftLabel)
        container.addSubview(leftField)
        container.addSubview(leftPx)
        container.addSubview(rightLabel)
        container.addSubview(rightField)
        container.addSubview(rightPx)

        alert.accessoryView = container

        if let win = window {
            alert.beginSheetModal(for: win) { [weak self] response in
                guard let self = self, response == .alertFirstButtonReturn else { return }
                let top = max(0, CGFloat(Double(topField.stringValue) ?? 0))
                let bottom = max(0, CGFloat(Double(bottomField.stringValue) ?? 0))
                let left = max(0, CGFloat(Double(leftField.stringValue) ?? 0))
                let right = max(0, CGFloat(Double(rightField.stringValue) ?? 0))

                guard (top + bottom + left + right) > 0 else { return }

                let newW = self.model.size.width + left + right
                let newH = self.model.size.height + top + bottom
                let newSize = CGSize(width: newW, height: newH)
                let offset = CGPoint(x: left, y: top)

                self.model.resizeCanvas(to: newSize, offset: offset, backgroundColor: self.canvasView.secondaryColor)
                self.model.pushUndoState()
                self.canvasView.updateFrameSize()
                self.centerCanvasInScrollView()
            }
        }
    }
}
