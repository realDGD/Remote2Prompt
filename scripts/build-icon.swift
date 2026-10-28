import CoreGraphics
import Foundation
import ImageIO

// Original RC003 silhouette and button geometry. No SF Symbol artwork or external image assets.
// Rasterization uses system frameworks and does not require an unlocked GUI session.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: size * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
        context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
        func color(_ value: CGFloat) -> CGColor { CGColor(colorSpace: space, components: [value, value, value, 1])! }
        func round(_ rect: CGRect, _ radius: CGFloat, _ fill: CGColor) {
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.setFillColor(fill); context.fillPath()
        }
        func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ fill: CGColor) {
            context.setFillColor(fill)
            context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }
        let plate = color(0.96)
        let ink = color(0.17)
        round(CGRect(x: 48, y: 48, width: 928, height: 928), 205, plate)
        // A slightly wider optical body at 16/32 pt keeps the two button columns distinct.
        let small = points <= 32
        let width: CGFloat = small ? 320 : 288
        round(CGRect(x: 512 - width / 2, y: 108, width: width, height: 808), 60, ink)
        let column: CGFloat = small ? 70 : 64
        let button: CGFloat = small ? 30 : 27
        // Power + voice, then the independent navigation ring and central confirmation key.
        circle(512 - column, 864, 22, plate)
        circle(512 + column, 864, 22, plate)
        circle(512, 710, 108, plate)
        circle(512, 710, 65, ink)
        circle(512, 710, 53, plate)
        // Back / home / menu, with the RC003 vertical volume rocker and lower TV key.
        for y: CGFloat in [554, 466, 378] { circle(512 - column, y, button, plate) }
        round(CGRect(x: 512 + column - button, y: 439, width: button * 2, height: 142), button, plate)
        circle(512 + column, 378, button, plate)
        guard let image = context.makeImage() else { exit(1) }
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        guard let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent(name) as CFURL,
            "public.png" as CFString, 1, nil) else { exit(1) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { exit(1) }
    }
}
