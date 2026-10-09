import Foundation
import AppKit

let svgPath = "/Volumes/T9/Development/TidebookApp/assets/gonordic/logo-wide.svg"
var svgContent = try! String(contentsOfFile: svgPath, encoding: .utf8)

// Replace black fill with white fill for the typography
svgContent = svgContent.replacingOccurrences(of: "fill=\"#000\"", with: "fill=\"#FFFFFF\"")
svgContent = svgContent.replacingOccurrences(of: "fill=\"#000000\"", with: "fill=\"#FFFFFF\"")

let whiteSvgPath = "/Volumes/T9/Development/TidebookApp/assets/gonordic/logo_white.svg"
try! svgContent.write(toFile: whiteSvgPath, atomically: true, encoding: .utf8)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1044,
    pixelsHigh: 124,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: 1044, height: 124)

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
ctx.imageInterpolation = .high
NSGraphicsContext.current = ctx

let img = NSImage(contentsOfFile: whiteSvgPath)!
img.draw(in: NSRect(x: 0, y: 0, width: 1044, height: 124), from: .zero, operation: .copy, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

if let data = rep.representation(using: .png, properties: [:]) {
    try! data.write(to: URL(fileURLWithPath: "/Volumes/T9/Development/TidebookApp/assets/gonordic/logo_white.png"))
    print("logo_white.png generated successfully!")
}
