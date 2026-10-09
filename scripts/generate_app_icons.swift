import AppKit

let masterSize: CGFloat = 1024

// SVG string for the Chevron emblem (isolated and scaled)
let chevronSvg = """
<svg viewBox="220 0 42 32" xmlns="http://www.w3.org/2000/svg">
    <path d="M229.354 31c-.073 0-.11-.09-.058-.143l16.596-16.907c.724-.742 2.114-1.55 3.226-1.55h11.8c.073 0 .11.092.058.144L244.382 29.45c-.787.808-2.091 1.55-3.205 1.55h-11.823z" fill="#C2C2BF"/>
    <path d="M247.398 12.354c-1.077-.109-2.234-.717-3.008-1.503-2.339-2.378-6.784-6.943-9.088-9.307C234.41.629 233.266 0 232.004 0h-10.09c-.075 0-.112.093-.06.147l10.416 10.692c.882.905 1.998 1.562 3.245 1.562h11.88c.012 0 .021-.01.021-.024 0-.011-.008-.022-.02-.023h.002z" fill="#A81212"/>
</svg>
"""

let chevronData = chevronSvg.data(using: .utf8)!
let chevronImage = NSImage(data: chevronData)!

func renderAppIcon(darkTheme: Bool) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(masterSize),
        pixelsHigh: Int(masterSize),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: masterSize, height: masterSize)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx

    let rect = NSRect(x: 0, y: 0, width: masterSize, height: masterSize)

    if darkTheme {
        // Luxury Deep Pine Gradient (#002A2A to #074849)
        let grad = NSGradient(colors: [
            NSColor(red: 0x00/255.0, green: 0x24/255.0, blue: 0x24/255.0, alpha: 1.0),
            NSColor(red: 0x07/255.0, green: 0x48/255.0, blue: 0x49/255.0, alpha: 1.0)
        ])!
        grad.draw(in: rect, angle: -45)
    } else {
        NSColor(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xF7/255.0, alpha: 1.0).setFill()
        rect.fill()
    }

    // Draw the Chevron Wings centered in upper-middle
    let chevronW: CGFloat = 480
    let chevronH: CGFloat = (32.0 / 42.0) * chevronW
    let chevronX = (masterSize - chevronW) / 2
    let chevronY = (masterSize - chevronH) / 2 + 80

    chevronImage.draw(
        in: NSRect(x: chevronX, y: chevronY, width: chevronW, height: chevronH),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
    )

    // Draw "GO NORDIC" Typography below
    let fontName = "Georgia-Bold"
    let font = NSFont(name: fontName, size: 76) ?? NSFont.boldSystemFont(ofSize: 76)
    let textColor = darkTheme ? NSColor.white : NSColor(red: 0x07/255.0, green: 0x48/255.0, blue: 0x49/255.0, alpha: 1.0)
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
        .paragraphStyle: paragraphStyle,
        .kern: 5.0
    ]
    
    let text = "GO NORDIC"
    let textRect = NSRect(x: 50, y: chevronY - 120, width: masterSize - 100, height: 90)
    text.draw(in: textRect, withAttributes: attrs)

    // Subtitle "CRUISELINE"
    let subFont = NSFont(name: "HelveticaNeue-Medium", size: 36) ?? NSFont.systemFont(ofSize: 36, weight: .medium)
    let subColor = darkTheme ? NSColor(red: 0xA9/255.0, green: 0xFE/255.0, blue: 0x34/255.0, alpha: 1.0) : NSColor(red: 0xA8/255.0, green: 0x12/255.0, blue: 0x12/255.0, alpha: 1.0)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: subColor,
        .paragraphStyle: paragraphStyle,
        .kern: 12.0
    ]
    let subText = "CRUISELINE"
    let subRect = NSRect(x: 50, y: chevronY - 180, width: masterSize - 100, height: 50)
    subText.draw(in: subRect, withAttributes: subAttrs)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let repDark = renderAppIcon(darkTheme: true)
let repLight = renderAppIcon(darkTheme: false)

if let dataDark = repDark.representation(using: .png, properties: [:]) {
    try! dataDark.write(to: URL(fileURLWithPath: "/Volumes/T9/Development/TidebookApp/assets/gonordic/app_icon.png"))
    try! dataDark.write(to: URL(fileURLWithPath: "/Volumes/T9/Development/TidebookApp/assets/gonordic/app_icon_dark.png"))
    print("Master app_icon.png (1024x1024) created successfully")
}
if let dataLight = repLight.representation(using: .png, properties: [:]) {
    try! dataLight.write(to: URL(fileURLWithPath: "/Volumes/T9/Development/TidebookApp/assets/gonordic/app_icon_light.png"))
    print("app_icon_light.png created successfully")
}
