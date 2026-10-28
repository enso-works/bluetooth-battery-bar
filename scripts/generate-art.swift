// Renders the app icon and README artwork.
// Usage: swift scripts/generate-art.swift   (run from the repo root)

import AppKit

// MARK: - Palette

func hex(_ value: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha)
}

let tealLight = hex(0x5EEAD4)
let teal = hex(0x14B8A6)
let tealDark = hex(0x0F5F66)
let night = hex(0x061A1D)
let nightLight = hex(0x0E3A3F)
let menuPanel = hex(0x1D2729)
let red = hex(0xF87171)

// MARK: - Rendering

func render(_ size: CGSize, to path: String, draw: (CGRect) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

func withShadow(blur: CGFloat, offsetY: CGFloat, alpha: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

@discardableResult
func drawText(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor, maxWidth: CGFloat = 10_000) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = size * 0.18
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    let bounds = string.boundingRect(with: CGSize(width: maxWidth, height: 10_000), options: [.usesLineFragmentOrigin])
    // `point` is the top-left corner of the text block.
    string.draw(with: CGRect(x: point.x, y: point.y - bounds.height, width: maxWidth, height: bounds.height),
                options: [.usesLineFragmentOrigin])
    return bounds.height
}

/// Draws single-line text whose top-right corner is `point`.
func drawTextRight(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let string = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    let textSize = string.size()
    string.draw(at: CGPoint(x: point.x - textSize.width, y: point.y - textSize.height))
}

/// Soft radial glow that fades to fully transparent, with no visible edge.
func drawGlow(center: CGPoint, radius: CGFloat, color: NSColor, alpha: CGFloat) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let colors = [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

func drawSymbol(_ name: String, in rect: CGRect, color: NSColor, weight: NSFont.Weight = .semibold) {
    let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: weight)
        .applying(.init(paletteColors: [color]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
    let size = image.size
    let scale = min(rect.width / size.width, rect.height / size.height)
    let drawRect = CGRect(x: rect.midX - size.width * scale / 2, y: rect.midY - size.height * scale / 2,
                          width: size.width * scale, height: size.height * scale)
    image.draw(in: drawRect)
}

// MARK: - Icon

/// Draws the icon artwork designed on a 1024 grid into `rect`: a battery above a keyboard.
func drawIcon(in rect: CGRect) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.minX, yBy: rect.minY)
    transform.scale(by: rect.width / 1024)
    transform.concat()

    // Squircle background following the macOS icon grid.
    let tile = NSBezierPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    withShadow(blur: 28, offsetY: -12, alpha: 0.35) {
        NSGradient(starting: tealLight, ending: tealDark)!.draw(in: tile, angle: -60)
    }
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    drawGlow(center: CGPoint(x: 300, y: 900), radius: 700, color: .white, alpha: 0.22)
    NSGraphicsContext.restoreGraphicsState()

    // Battery, about three quarters full.
    let body = NSBezierPath(roundedRect: CGRect(x: 262, y: 575, width: 450, height: 215), xRadius: 58, yRadius: 58)
    body.lineWidth = 34
    withShadow(blur: 18, offsetY: -6, alpha: 0.22) {
        NSColor.white.setStroke()
        body.stroke()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: CGRect(x: 728, y: 638, width: 42, height: 90), xRadius: 16, yRadius: 16).fill()
    }
    NSColor.white.setFill()
    NSBezierPath(roundedRect: CGRect(x: 306, y: 619, width: 270, height: 127), xRadius: 26, yRadius: 26).fill()

    // Keyboard with three rows of keys.
    let keyboard = CGRect(x: 200, y: 215, width: 624, height: 270)
    withShadow(blur: 22, offsetY: -8, alpha: 0.3) {
        NSColor.white.setFill()
        NSBezierPath(roundedRect: keyboard, xRadius: 52, yRadius: 52).fill()
    }
    let pad: CGFloat = 39, keyH: CGFloat = 52, gap: CGFloat = 18, keyGap: CGFloat = 14
    let innerW = keyboard.width - pad * 2
    let keyW = (innerW - keyGap * 8) / 9
    tealDark.withAlphaComponent(0.3).setFill()
    for row in 0..<3 {
        let y = keyboard.maxY - pad - keyH - CGFloat(row) * (keyH + gap)
        let widths: [CGFloat] = row < 2
            ? Array(repeating: keyW, count: 9)
            : [keyW, keyW, innerW - keyW * 4 - keyGap * 4, keyW, keyW]
        var x = keyboard.minX + pad
        for width in widths {
            NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: keyH), xRadius: 12, yRadius: 12).fill()
            x += width + keyGap
        }
    }

    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - README artwork

func drawBackdrop(_ rect: CGRect, radius: CGFloat) {
    let card = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGradient(starting: nightLight, ending: night)!.draw(in: card, angle: -35)
    NSGraphicsContext.saveGraphicsState()
    card.addClip()
    drawGlow(center: CGPoint(x: rect.minX + 280, y: rect.midY), radius: 760, color: teal, alpha: 0.45)
    drawGlow(center: CGPoint(x: rect.maxX - 120, y: rect.maxY), radius: 520, color: tealDark, alpha: 0.5)
    NSGraphicsContext.restoreGraphicsState()
}

func drawPill(_ text: String, symbol: String, at origin: CGPoint) -> CGFloat {
    let font = NSFont.systemFont(ofSize: 24, weight: .medium)
    let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
    let width = textWidth + 92
    let pill = NSBezierPath(roundedRect: CGRect(x: origin.x, y: origin.y, width: width, height: 56), xRadius: 28, yRadius: 28)
    NSColor.white.withAlphaComponent(0.1).setFill()
    pill.fill()
    NSColor.white.withAlphaComponent(0.18).setStroke()
    pill.lineWidth = 1.5
    pill.stroke()
    drawSymbol(symbol, in: CGRect(x: origin.x + 22, y: origin.y + 14, width: 28, height: 28), color: tealLight)
    drawText(text, at: CGPoint(x: origin.x + 62, y: origin.y + 42), size: 24, weight: .medium, color: .white)
    return width
}

func drawBanner(_ rect: CGRect) {
    drawBackdrop(rect, radius: 36)
    drawIcon(in: CGRect(x: 50, y: rect.midY - 230, width: 460, height: 460))
    let left: CGFloat = 530
    var y = rect.midY + 205
    y -= drawText("Bluetooth", at: CGPoint(x: left, y: y), size: 76, weight: .heavy, color: .white)
    y -= drawText("Battery Bar", at: CGPoint(x: left, y: y), size: 76, weight: .heavy, color: tealLight)
    y -= 24
    y -= drawText("The battery level macOS doesn't show you, for keyboards,\nmice and controllers. Free, open source, no trials.",
                  at: CGPoint(x: left, y: y), size: 30, weight: .regular, color: NSColor.white.withAlphaComponent(0.72), maxWidth: 1000)
    y -= 44
    var x = left
    x += drawPill("Keychron and more", symbol: "keyboard", at: CGPoint(x: x, y: y - 56)) + 16
    x += drawPill("Bluetooth LE", symbol: "dot.radiowaves.left.and.right", at: CGPoint(x: x, y: y - 56)) + 16
    _ = drawPill("Low battery alerts", symbol: "bell.fill", at: CGPoint(x: x, y: y - 56))
}

func drawFeatureCard(_ rect: CGRect, symbol: String, title: String, body: String) {
    let card = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    NSColor.white.withAlphaComponent(0.06).setFill()
    card.fill()
    NSColor.white.withAlphaComponent(0.14).setStroke()
    card.lineWidth = 1.5
    card.stroke()

    let badge = CGRect(x: rect.minX + 36, y: rect.maxY - 36 - 88, width: 88, height: 88)
    NSGradient(starting: tealLight, ending: tealDark)!
        .draw(in: NSBezierPath(roundedRect: badge, xRadius: 22, yRadius: 22), angle: -60)
    drawSymbol(symbol, in: badge.insetBy(dx: 22, dy: 22), color: .white)

    var y = badge.minY - 30
    y -= drawText(title, at: CGPoint(x: rect.minX + 36, y: y), size: 32, weight: .bold, color: .white, maxWidth: rect.width - 72)
    y -= 12
    drawText(body, at: CGPoint(x: rect.minX + 36, y: y), size: 23, weight: .regular,
             color: NSColor.white.withAlphaComponent(0.7), maxWidth: rect.width - 72)
}

func drawFeatures(_ rect: CGRect) {
    drawBackdrop(rect, radius: 36)
    let cards: [(String, String, String)] = [
        ("keyboard", "Bluetooth keyboards",
         "Keychron K-series and other keyboards that report their battery over HID. macOS never shows it."),
        ("computermouse", "Mice, headphones, splits",
         "Any Bluetooth LE device with the standard battery service. Each half of a split keyboard on its own."),
        ("gamecontroller", "Controllers and alerts",
         "Xbox, PlayStation and Switch Pro controllers, with charging. One notification when anything runs low."),
    ]
    let pad: CGFloat = 48, gap: CGFloat = 28
    let width = (rect.width - pad * 2 - gap * 2) / 3
    for (index, card) in cards.enumerated() {
        let x = rect.minX + pad + CGFloat(index) * (width + gap)
        drawFeatureCard(CGRect(x: x, y: rect.minY + pad, width: width, height: rect.height - pad * 2),
                        symbol: card.0, title: card.1, body: card.2)
    }
}

/// The menu bar item and its open menu, drawn to look like macOS in dark mode.
func drawMenu(_ rect: CGRect) {
    drawBackdrop(rect, radius: 36)
    let left: CGFloat = 60
    var y = rect.maxY - 150
    y -= drawText("Every battery,", at: CGPoint(x: left, y: y), size: 54, weight: .heavy, color: .white)
    y -= drawText("one click away", at: CGPoint(x: left, y: y), size: 54, weight: .heavy, color: tealLight)
    y -= 22
    drawText("The lowest level sits in the menu bar\nand turns red when it runs low.",
             at: CGPoint(x: left, y: y), size: 26, weight: .regular, color: NSColor.white.withAlphaComponent(0.72), maxWidth: 520)

    // Menu bar strip with the highlighted status item.
    let barHeight: CGFloat = 56
    NSColor.white.withAlphaComponent(0.08).setFill()
    NSBezierPath(rect: CGRect(x: rect.minX, y: rect.maxY - barHeight, width: rect.width, height: barHeight)).fill()
    let item = CGRect(x: 780, y: rect.maxY - barHeight + 8, width: 132, height: 40)
    NSColor.white.withAlphaComponent(0.2).setFill()
    NSBezierPath(roundedRect: item, xRadius: 10, yRadius: 10).fill()
    // The lowest device, red because it is below the low-battery level.
    drawSymbol("gamecontroller", in: CGRect(x: item.minX + 14, y: item.minY + 10, width: 36, height: 20), color: .white, weight: .regular)
    drawText("18%", at: CGPoint(x: item.minX + 60, y: item.maxY - 6), size: 24, weight: .medium, color: red)

    // The open menu.
    let panel = CGRect(x: 640, y: 56, width: 560, height: rect.maxY - barHeight - 12 - 56)
    withShadow(blur: 30, offsetY: -10, alpha: 0.45) {
        menuPanel.withAlphaComponent(0.97).setFill()
        NSBezierPath(roundedRect: panel, xRadius: 20, yRadius: 20).fill()
    }
    NSColor.white.withAlphaComponent(0.12).setStroke()
    let outline = NSBezierPath(roundedRect: panel, xRadius: 20, yRadius: 20)
    outline.lineWidth = 1.5
    outline.stroke()

    let devices: [(String, String, String, String, Bool)] = [
        ("keyboard", "Keychron K2", "56%", "Bluetooth HID · updated just now", false),
        ("computermouse", "HP 250/255 Dual Mouse", "88%", "Bluetooth LE · updated just now", false),
        ("gamecontroller", "DualSense Wireless Controller", "18%", "Game controller · updated 2 minutes ago", true),
    ]
    var top = panel.maxY - 22
    for (symbol, name, percent, detail, isLow) in devices {
        drawSymbol(symbol, in: CGRect(x: panel.minX + 26, y: top - 46, width: 34, height: 26), color: .white, weight: .regular)
        drawText(name, at: CGPoint(x: panel.minX + 78, y: top - 6), size: 25, weight: .regular, color: .white)
        drawTextRight(percent, at: CGPoint(x: panel.maxX - 30, y: top - 6), size: 25, weight: .regular, color: isLow ? red : .white)
        drawText(detail, at: CGPoint(x: panel.minX + 78, y: top - 42), size: 19, weight: .regular, color: NSColor.white.withAlphaComponent(0.5))
        top -= 86
    }

    func separator() {
        NSColor.white.withAlphaComponent(0.14).setFill()
        NSBezierPath(rect: CGRect(x: panel.minX + 22, y: top - 4, width: panel.width - 44, height: 1.5)).fill()
        top -= 16
    }
    func menuItem(_ title: String, _ shortcut: String) {
        drawText(title, at: CGPoint(x: panel.minX + 30, y: top - 6), size: 24, weight: .regular, color: .white)
        drawTextRight(shortcut, at: CGPoint(x: panel.maxX - 30, y: top - 6), size: 24, weight: .regular, color: NSColor.white.withAlphaComponent(0.45))
        top -= 46
    }
    separator()
    menuItem("Refresh", "⌘R")
    separator()
    menuItem("Settings…", "⌘,")
    menuItem("Check for Updates…", "")
    separator()
    menuItem("Quit Bluetooth Battery Bar", "⌘Q")
}

/// 1200x630 social preview card for GitHub.
func drawSocialCard(_ rect: CGRect) {
    drawBackdrop(rect, radius: 0)
    drawIcon(in: CGRect(x: rect.midX - 150, y: rect.maxY - 330, width: 300, height: 300))
    let title = NSAttributedString(string: "Bluetooth Battery Bar", attributes: [
        .font: NSFont.systemFont(ofSize: 62, weight: .heavy), .foregroundColor: NSColor.white])
    title.draw(at: CGPoint(x: rect.midX - title.size().width / 2, y: 170))
    let tagline = NSAttributedString(string: "The battery level macOS doesn't show you. Free forever.", attributes: [
        .font: NSFont.systemFont(ofSize: 30, weight: .regular), .foregroundColor: NSColor.white.withAlphaComponent(0.72)])
    tagline.draw(at: CGPoint(x: rect.midX - tagline.size().width / 2, y: 110))
}

// MARK: - Main

try? FileManager.default.createDirectory(atPath: "docs/images", withIntermediateDirectories: true)

render(CGSize(width: 1024, height: 1024), to: "Resources/AppIcon-1024.png") { drawIcon(in: $0) }
render(CGSize(width: 512, height: 512), to: "docs/images/icon.png") { drawIcon(in: $0) }
render(CGSize(width: 1600, height: 640), to: "docs/images/banner.png") { drawBanner($0) }
render(CGSize(width: 1600, height: 400), to: "docs/images/features.png") { drawFeatures($0) }
render(CGSize(width: 1260, height: 640), to: "docs/images/menu.png") { drawMenu($0) }
render(CGSize(width: 1200, height: 630), to: "docs/images/social-card.png") { drawSocialCard($0) }
