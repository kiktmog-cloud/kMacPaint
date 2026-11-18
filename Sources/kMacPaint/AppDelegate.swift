import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        windowController = MainWindowController()
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Do NOT quit app when window closes (keeps app alive in Dock / menu bar)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openNewOrExistingWindow()
        }
        return true
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let wc = windowController, wc.window?.isVisible == true else { return .terminateNow }
        return wc.promptSaveIfModified() ? .terminateNow : .terminateCancel
    }

    public func openNewOrExistingWindow() {
        if windowController == nil {
            windowController = MainWindowController()
        }
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        windowController?.centerCanvasInScrollView()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "kMacPaint 정보", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "kMacPaint 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "파일")
        fileMenu.addItem(withTitle: "새로 만들기", action: #selector(newDoc), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "열기...", action: #selector(openDoc), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "이미지 삽입(얹기)...", action: #selector(insertImg), keyEquivalent: "i")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "저장", action: #selector(saveDoc), keyEquivalent: "s")
        let saveAsItem = NSMenuItem(title: "다른 이름으로 저장...", action: #selector(saveAsDoc), keyEquivalent: "S")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(saveAsItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "창 닫기", action: #selector(closeDoc), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "실행 취소", action: #selector(undoDoc), keyEquivalent: "z")
        
        let redoItem = NSMenuItem(title: "다시 실행", action: #selector(redoDoc), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "잘라내기", action: #selector(cutDoc), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(copyDoc), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(pasteDoc), keyEquivalent: "v")
        editMenu.addItem(withTitle: "삭제", action: #selector(deleteDoc), keyEquivalent: "\u{08}")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "전체 선택", action: #selector(selectAllDoc), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. View Menu (보기 - 확대/축소)
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "보기")
        viewMenu.addItem(withTitle: "확대", action: #selector(zoomInDoc), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "축소", action: #selector(zoomOutDoc), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "100% (원래 크기)", action: #selector(resetZoomDoc), keyEquivalent: "0")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 5. Format Menu (서식)
        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "서식")
        formatMenu.addItem(withTitle: "글꼴 패널 표시", action: #selector(showFontPanel), keyEquivalent: "t")
        formatMenu.addItem(NSMenuItem.separator())
        formatMenu.addItem(withTitle: "굵게", action: #selector(toggleBold), keyEquivalent: "b")
        formatMenu.addItem(withTitle: "기울임꼴", action: #selector(toggleItalic), keyEquivalent: "i")
        formatMenu.addItem(withTitle: "밑줄", action: #selector(toggleUnderline), keyEquivalent: "u")
        formatMenuItem.submenu = formatMenu
        mainMenu.addItem(formatMenuItem)

        // 6. Image Menu
        let imageMenuItem = NSMenuItem()
        let imageMenu = NSMenu(title: "이미지")
        let resizeCanvasItem = NSMenuItem(title: "캔버스 크기 및 여백 확장...", action: #selector(showCanvasResizeDoc), keyEquivalent: "k")
        imageMenu.addItem(resizeCanvasItem)
        imageMenu.addItem(withTitle: "캔버스 화면 중앙 정렬", action: #selector(centerCanvasDoc), keyEquivalent: "")
        imageMenu.addItem(NSMenuItem.separator())
        imageMenu.addItem(withTitle: "캔버스 지우기", action: #selector(newDoc), keyEquivalent: "")
        imageMenuItem.submenu = imageMenu
        mainMenu.addItem(imageMenuItem)

        // 7. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "윈도우")
        windowMenu.addItem(withTitle: "창 닫기", action: #selector(closeDoc), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "최소화", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "전체 화면 / 최대화", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func newDoc() {
        openNewOrExistingWindow()
        windowController?.newDocument()
    }
    @objc private func openDoc() {
        openNewOrExistingWindow()
        windowController?.openDocument()
    }
    @objc private func insertImg() {
        openNewOrExistingWindow()
        windowController?.insertImageFile()
    }
    @objc private func saveDoc() { windowController?.saveDocument() }
    @objc private func saveAsDoc() { windowController?.saveDocumentAs() }
    @objc private func closeDoc() { windowController?.window?.performClose(nil) }
    @objc private func showCanvasResizeDoc() { windowController?.showCanvasSizeDialog() }
    @objc private func centerCanvasDoc() { windowController?.centerCanvasInScrollView() }
    @objc private func undoDoc() { windowController?.undo() }
    @objc private func redoDoc() { windowController?.redo() }
    @objc private func cutDoc() { windowController?.cutSelection() }
    @objc private func copyDoc() { windowController?.copySelection() }
    @objc private func pasteDoc() { windowController?.pasteFromClipboard() }
    @objc private func deleteDoc() { windowController?.deleteSelection() }
    @objc private func selectAllDoc() { windowController?.selectAll() }
    @objc private func zoomInDoc() { windowController?.zoomIn() }
    @objc private func zoomOutDoc() { windowController?.zoomOut() }
    @objc private func resetZoomDoc() { windowController?.resetZoom() }
    @objc private func showFontPanel() { NSFontManager.shared.orderFrontFontPanel(nil) }
    @objc private func toggleBold() { windowController?.canvasView.activeTextEditor?.toggleBold() }
    @objc private func toggleItalic() { windowController?.canvasView.activeTextEditor?.toggleItalic() }
    @objc private func toggleUnderline() { windowController?.canvasView.activeTextEditor?.toggleUnderline() }
}
