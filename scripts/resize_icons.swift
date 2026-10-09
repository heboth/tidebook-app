import AppKit

let masterPath = "/Volumes/T9/Development/TidebookApp/assets/gonordic/app_icon.png"
guard let masterImage = NSImage(contentsOfFile: masterPath) else {
    print("Failed to load master app icon")
    exit(1)
}

func exportPng(image: NSImage, targetPixelSize: Int, destinationPath: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetPixelSize,
        pixelsHigh: targetPixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: targetPixelSize, height: targetPixelSize)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx

    image.draw(
        in: NSRect(x: 0, y: 0, width: targetPixelSize, height: targetPixelSize),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1.0
    )

    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: destinationPath)
        try! data.write(to: url)
        print("Generated: \(destinationPath) (\(targetPixelSize)x\(targetPixelSize))")
    }
}

let iosDir = "/Volumes/T9/Development/TidebookApp/ios/Runner/Assets.xcassets/AppIcon.appiconset"

let iosIcons: [(String, Int)] = [
    ("Icon-App-1024x1024@1x.png", 1024),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@1x.png", 20)
]

for (filename, size) in iosIcons {
    exportPng(image: masterImage, targetPixelSize: size, destinationPath: "\(iosDir)/\(filename)")
}

let androidDir = "/Volumes/T9/Development/TidebookApp/android/app/src/main/res"

let androidIcons: [(String, Int)] = [
    ("mipmap-mdpi/ic_launcher.png", 48),
    ("mipmap-hdpi/ic_launcher.png", 72),
    ("mipmap-xhdpi/ic_launcher.png", 96),
    ("mipmap-xxhdpi/ic_launcher.png", 144),
    ("mipmap-xxxhdpi/ic_launcher.png", 192)
]

for (relPath, size) in androidIcons {
    exportPng(image: masterImage, targetPixelSize: size, destinationPath: "\(androidDir)/\(relPath)")
}

print("All iOS and Android app icons successfully generated!")
