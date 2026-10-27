import CoreGraphics
import Foundation
import ImageIO

// Original vector geometry, rasterized with system frameworks; no image assets or GUI session needed.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
        context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
        func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(colorSpace: space, components: [r,g,b,1])! }
        func round(_ rect: CGRect, _ radius: CGFloat, _ fill: CGColor) {
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.setFillColor(fill); context.fillPath()
        }
        let ink = color(0.10,0.28,0.56)
        let white = color(0.94,0.97,1)
        context.saveGState()
        context.addPath(CGPath(roundedRect: CGRect(x: 48, y: 48, width: 928, height: 928), cornerWidth: 205, cornerHeight: 205, transform: nil))
        context.clip()
        let gradient = CGGradient(colorsSpace: space, colors: [color(0.13,0.58,0.95),color(0.12,0.25,0.66)] as CFArray, locations: [0,1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 220,y: 920), end: CGPoint(x: 820,y: 80), options: [])
        context.restoreGState()
        round(CGRect(x: 302,y: 112,width: 420,height: 800), 85, white)
        context.setFillColor(ink)
        context.fillEllipse(in: CGRect(x: 366,y: 500,width: 292,height: 292))
        context.setStrokeColor(white); context.setLineWidth(10)
        context.strokeEllipse(in: CGRect(x: 452,y: 586,width: 120,height: 120))
        for point in [CGPoint(x: 408,y: 386),CGPoint(x: 408,y: 284),CGPoint(x: 408,y: 182)] {
            context.setFillColor(ink); context.fillEllipse(in: CGRect(x: point.x - 28,y: point.y - 28,width: 56,height: 56))
        }
        round(CGRect(x: 582,y: 256,width: 68,height: 164), 34, ink)
        round(CGRect(x: 584,y: 156,width: 64,height: 52), 15, ink)
        context.setStrokeColor(ink); context.setLineWidth(14); context.setLineCap(.round)
        context.addArc(center: CGPoint(x: 408,y: 848), radius: 27, startAngle: .pi * 0.25, endAngle: .pi * 2.75, clockwise: false)
        context.strokePath()
        context.move(to: CGPoint(x: 408,y: 844)); context.addLine(to: CGPoint(x: 408,y: 884)); context.strokePath()
        round(CGRect(x: 604,y: 836,width: 24,height: 52), 12, ink)
        context.move(to: CGPoint(x: 589,y: 858)); context.addLine(to: CGPoint(x: 589,y: 839))
        context.addQuadCurve(to: CGPoint(x: 643,y: 839), control: CGPoint(x: 616,y: 807))
        context.addLine(to: CGPoint(x: 643,y: 858)); context.strokePath()
        context.move(to: CGPoint(x: 616,y: 819)); context.addLine(to: CGPoint(x: 616,y: 806)); context.strokePath()
        guard let image = context.makeImage() else { exit(1) }
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        guard let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil) else { exit(1) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { exit(1) }
    }
}
