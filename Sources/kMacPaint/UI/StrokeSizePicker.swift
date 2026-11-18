import AppKit

public protocol StrokeSizePickerDelegate: AnyObject {
    func strokeSizePickerDidSelectWidth(_ width: CGFloat)
}

public final class StrokeSizePicker: NSPopUpButton {
    public weak var sizeDelegate: StrokeSizePickerDelegate?

    public static let sizes: [CGFloat] = [1.0, 2.0, 3.0, 5.0, 8.0, 12.0, 16.0]

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 80, height: 28), pullsDown: false)
        bezelStyle = .rounded
        
        for size in Self.sizes {
            addItem(withTitle: "\(Int(size)) px")
        }
        selectItem(withTitle: "3 px")
        
        target = self
        action = #selector(selectionChanged(_:))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func selectionChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        if index >= 0 && index < Self.sizes.count {
            sizeDelegate?.strokeSizePickerDidSelectWidth(Self.sizes[index])
        }
    }
}
