import AppKit

public struct PixelColor: Equatable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public init(color: NSColor) {
        let rgb = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) ?? NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        self.r = UInt8(clamping: Int(rgb.redComponent * 255.0))
        self.g = UInt8(clamping: Int(rgb.greenComponent * 255.0))
        self.b = UInt8(clamping: Int(rgb.blueComponent * 255.0))
        self.a = UInt8(clamping: Int(rgb.alphaComponent * 255.0))
    }

    public func matches(_ other: PixelColor, tolerance: Int = 10) -> Bool {
        return abs(Int(self.r) - Int(other.r)) <= tolerance &&
               abs(Int(self.g) - Int(other.g)) <= tolerance &&
               abs(Int(self.b) - Int(other.b)) <= tolerance &&
               abs(Int(self.a) - Int(other.a)) <= tolerance
    }
}

public final class FloodFill {
    public static func execute(
        context: CGContext,
        point: CGPoint,
        fillColor: NSColor,
        tolerance: Int = 12
    ) {
        guard let data = context.data else { return }
        let width = context.width
        let height = context.height
        let bytesPerRow = context.bytesPerRow
        let bytesPerPixel = 4

        let startX = Int(point.x)
        let startY = Int(point.y)

        guard startX >= 0, startX < width, startY >= 0, startY < height else { return }

        let ptr = data.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)

        func getPixel(x: Int, y: Int) -> PixelColor {
            let offset = y * bytesPerRow + x * bytesPerPixel
            // Premultiplied or normal RGBA / BGRA depending on bitmap context
            // CGContext typically uses RGBA:
            return PixelColor(
                r: ptr[offset],
                g: ptr[offset + 1],
                b: ptr[offset + 2],
                a: ptr[offset + 3]
            )
        }

        func setPixel(x: Int, y: Int, color: PixelColor) {
            let offset = y * bytesPerRow + x * bytesPerPixel
            ptr[offset] = color.r
            ptr[offset + 1] = color.g
            ptr[offset + 2] = color.b
            ptr[offset + 3] = color.a
        }

        let targetColor = getPixel(x: startX, y: startY)
        let replacementColor = PixelColor(color: fillColor)

        if targetColor.matches(replacementColor, tolerance: tolerance) {
            return
        }

        // Bitset for visited tracking: 1 bit per pixel (only 1MB RAM even on 4K)
        var visited = [UInt64](repeating: 0, count: (width * height + 63) / 64)

        @inline(__always)
        func isVisited(_ x: Int, _ y: Int) -> Bool {
            let idx = y * width + x
            return (visited[idx >> 6] & (1 << (idx & 63))) != 0
        }

        @inline(__always)
        func markVisited(_ x: Int, _ y: Int) {
            let idx = y * width + x
            visited[idx >> 6] |= (1 << (idx & 63))
        }

        @inline(__always)
        func checkFill(_ x: Int, _ y: Int) -> Bool {
            if isVisited(x, y) { return false }
            markVisited(x, y)
            return getPixel(x: x, y: y).matches(targetColor, tolerance: tolerance)
        }

        // Scanline Stack: stores (x, y) span seeds
        markVisited(startX, startY)
        var stack = [Int]()
        stack.reserveCapacity(2048)
        stack.append(startX)
        stack.append(startY)

        while !stack.isEmpty {
            let y = stack.removeLast()
            let x = stack.removeLast()

            // Find leftmost matching pixel
            var left = x
            while left > 0 && checkFill(left - 1, y) {
                left -= 1
            }

            // Find rightmost matching pixel
            var right = x
            while right < width - 1 && checkFill(right + 1, y) {
                right += 1
            }

            // Fill span
            for i in left...right {
                setPixel(x: i, y: y, color: replacementColor)
            }

            // Scan adjacent rows above and below
            for dy in [-1, 1] {
                let ny = y + dy
                guard ny >= 0 && ny < height else { continue }
                var inSpan = false
                for i in left...right {
                    if checkFill(i, ny) {
                        if !inSpan {
                            stack.append(i)
                            stack.append(ny)
                            inSpan = true
                        }
                    } else {
                        inSpan = false
                    }
                }
            }
        }
    }
}
