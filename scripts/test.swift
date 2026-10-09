import AppKit

let svgPath = "/Volumes/T9/Development/TidebookApp/assets/gonordic/logo-wide.svg"
guard let image = NSImage(contentsOfFile: svgPath) else {
    print("Error loading SVG")
    exit(1)
}

let width: CGFloat = 1044
let height: CGFloat = 124

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
image.draw(in: NSRect(x: 0, y: 0, width: width, height: height), from: .zero, operation: .copy, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

if let data = rep.representation(using: .png, properties: [:]) {
    let outUrl = URL(fileURLWithPath: "/Volumes/T9/Development/TidebookApp/assets/gonordic/logo.png")
    try data.write(to: outUrl)
    print("logo.png written successfully, size: \(data.count) bytes")
}
