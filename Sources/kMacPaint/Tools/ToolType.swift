import AppKit

public enum ToolType: String, CaseIterable {
    case select = "Select"
    case pencil = "Pencil"
    case brush = "Brush"
    case eraser = "Eraser"
    case fill = "Fill"
    case colorPicker = "ColorPicker"
    case text = "Text"
    case line = "Line"
    case rectangle = "Rectangle"
    case roundedRect = "RoundedRect"
    case oval = "Oval"

    public var displayName: String {
        switch self {
        case .select: return "선택"
        case .pencil: return "연필"
        case .brush: return "브러시"
        case .eraser: return "지우개"
        case .fill: return "채우기"
        case .colorPicker: return "스포이드"
        case .text: return "텍스트"
        case .line: return "직선"
        case .rectangle: return "직사각형"
        case .roundedRect: return "둥근 직사각형"
        case .oval: return "타원"
        }
    }

    public var iconName: String {
        switch self {
        case .select: return "RectangularSelectionLarge"
        case .pencil: return "PencilTool"
        case .brush: return "BrushIcon"
        case .eraser: return "EraserTool"
        case .fill: return "FillTool"
        case .colorPicker: return "ColorPickerTool"
        case .text: return "TextTool"
        case .line: return "LineTool"
        case .rectangle: return "RectangleTool"
        case .roundedRect: return "RoundedRectTool"
        case .oval: return "OvalTool"
        }
    }
}
