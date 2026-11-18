import XCTest
@testable import kMacPaint

final class CanvasModelTests: XCTestCase {
    func testInitialCanvasState() {
        let model = CanvasModel(size: CGSize(width: 800, height: 600))
        XCTAssertEqual(model.size.width, 800)
        XCTAssertEqual(model.size.height, 600)
        XCTAssertFalse(model.isDirty, "New canvas model should be marked clean")
        XCTAssertFalse(model.canUndo, "Initial model cannot undo beyond initial snapshot")
        XCTAssertFalse(model.canRedo, "Initial model has empty redo stack")
    }

    func testCanvasResizeWithOffset() {
        let model = CanvasModel(size: CGSize(width: 400, height: 300))
        let targetSize = CGSize(width: 600, height: 500)
        let offset = CGPoint(x: 100, y: 100)

        model.resizeCanvas(to: targetSize, offset: offset, backgroundColor: .white)
        XCTAssertEqual(model.size.width, 600)
        XCTAssertEqual(model.size.height, 500)
        XCTAssertNotNil(model.currentCGImage())
    }

    func testUndoRedoLifecycle() {
        let model = CanvasModel(size: CGSize(width: 200, height: 200))
        XCTAssertFalse(model.isDirty)

        // Draw something into model context
        model.context.setFillColor(NSColor.red.cgColor)
        model.context.fill(CGRect(x: 10, y: 10, width: 50, height: 50))
        model.pushUndoState()

        XCTAssertTrue(model.canUndo)
        XCTAssertTrue(model.isDirty)

        model.undo()
        XCTAssertFalse(model.isDirty, "Undoing back to clean snapshot should mark model clean")
        XCTAssertTrue(model.canRedo)

        model.redo()
        XCTAssertTrue(model.isDirty)
    }

    func testDynamicUndoLimit() {
        let standardModel = CanvasModel(size: CGSize(width: 1024, height: 768))
        XCTAssertEqual(standardModel.maxUndoSteps, 35)

        let fourKModel = CanvasModel(size: CGSize(width: 3840, height: 2160))
        XCTAssertEqual(fourKModel.maxUndoSteps, 12)
    }

    func testPixelColorMatching() {
        let white = PixelColor(r: 255, g: 255, b: 255, a: 255)
        let nearWhite = PixelColor(r: 250, g: 250, b: 250, a: 255)
        let black = PixelColor(r: 0, g: 0, b: 0, a: 255)

        XCTAssertTrue(white.matches(nearWhite, tolerance: 10))
        XCTAssertFalse(white.matches(black, tolerance: 10))
    }
}
