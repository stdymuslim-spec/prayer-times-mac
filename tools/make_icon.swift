// Renders the 1024×1024 app icon PNG: a gold crescent and star on a deep green rounded square.
import AppKit

let canvas: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: an 824pt body centred in the 1024pt canvas.
let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(red: 0.07, green: 0.40, blue: 0.34, alpha: 1),
           ending: NSColor(red: 0.02, green: 0.15, blue: 0.18, alpha: 1))!.draw(in: body, angle: -90)

let gold = NSColor(red: 1.0, green: 0.84, blue: 0.52, alpha: 1)
gold.setFill()

// Crescent: the moon disc with an offset disc clipped away.
NSGraphicsContext.saveGraphicsState()
let bite = NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvas, height: canvas))
bite.appendOval(in: NSRect(x: 375, y: 365, width: 430, height: 430))
bite.windingRule = .evenOdd
bite.addClip()
NSBezierPath(ovalIn: NSRect(x: 220, y: 250, width: 500, height: 500)).fill()
NSGraphicsContext.restoreGraphicsState()

// Five-pointed star inside the crescent's opening.
let star = NSBezierPath()
let center = NSPoint(x: 680, y: 610)
for i in 0..<10 {
    let radius: CGFloat = i % 2 == 0 ? 80 : 32
    let angle = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
    let point = NSPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    i == 0 ? star.move(to: point) : star.line(to: point)
}
star.close()
star.fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
