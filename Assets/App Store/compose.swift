#!/usr/bin/env swift

import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let languages = ["en"]

/// Captures live in `Raw/<device>/<lang>/` and are written to `<device>/<lang>/`.
enum Device: String {
    case iPhone
    case iPad

    /// 6.9" iPhone and 13" iPad.
    var canvasSize: NSSize {
        switch self {
        case .iPhone: NSSize(width: 1320, height: 2868)
        case .iPad: NSSize(width: 2064, height: 2752)
        }
    }

    /// Text and margins are laid out for the iPhone canvas and scaled up by width.
    var scale: CGFloat { canvasSize.width / Device.iPhone.canvasSize.width }

    /// The bezel and corner radii, as fractions of the device's width.
    var bezel: CGFloat { self == .iPhone ? 0.028 : 0.022 }
    var cornerRadius: CGFloat { self == .iPhone ? 0.15 : 0.045 }

    func rawDir(_ language: String) -> URL {
        scriptDir.appendingPathComponent("Raw").appendingPathComponent(rawValue)
            .appendingPathComponent(language)
    }

    func outDir(_ language: String) -> URL {
        scriptDir.appendingPathComponent(rawValue).appendingPathComponent(language)
    }
}

struct Copy {
    let header: String
    let caption: String
}

struct Screenshot {
    let name: String
    /// Keyed by device, then by language code. A language without copy is skipped.
    let copy: [Device: [String: Copy]]
}

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

// Mint fading into sky blue, with near-black text, as in the Pixelmator Pro designs.
let gradientTop = color(0xDEF1E9)
let gradientBottom = color(0x8ABAF7)
let textColor = color(0x1B1616)

let screenshots = [
    Screenshot(
        name: "01-apps",
        copy: [
            .iPhone: ["en": Copy(header: "Xcode Cloud", caption: "Now at your fingertips")],
            .iPad: ["en": Copy(header: "Xcode Cloud", caption: "Now in your palms")],
        ]
    ),
    Screenshot(
        name: "02-builds",
        copy: [
            .iPhone: ["en": Copy(header: "View and start builds", caption: "With just a tap (or two)")],
            .iPad: ["en": Copy(header: "View and start builds", caption: "With just a tap (or click)")],
        ]
    ),
]

// MARK: - Text

/// Archivo, bundled in `Fonts/`. Falls back to the system font if it fails to load.
for name in ["Archivo-Bold", "Archivo-Regular"] {
    let url = scriptDir.appendingPathComponent("Fonts").appendingPathComponent("\(name).ttf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

func archivo(ofSize size: CGFloat, bold: Bool) -> NSFont {
    NSFont(name: bold ? "Archivo-Bold" : "Archivo-Regular", size: size)
        ?? NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
}

/// One line of text at the largest size up to `size` that fits `maxWidth`.
struct Line {
    let text: NSAttributedString
    let size: NSSize
    /// The glyphs' bounds, relative to the start of the baseline.
    let ink: NSRect

    init(_ text: String, size: CGFloat, bold: Bool, maxWidth: CGFloat) {
        var fontSize = size
        var attributed = NSAttributedString(string: text)
        var lineSize = NSSize.zero
        while fontSize > 10 {
            attributed = NSAttributedString(string: text, attributes: [
                .font: archivo(ofSize: fontSize, bold: bold),
                .foregroundColor: textColor,
                // Slightly tight, like the designs.
                .kern: -fontSize * 0.02,
            ])
            lineSize = attributed.size()
            if lineSize.width <= maxWidth { break }
            fontSize -= 2
        }
        self.text = attributed
        self.size = lineSize
        // Centering by the line box leaves the text looking off, since it carries space
        // above the capitals and below the baseline, so the glyphs are measured instead.
        ink = attributed.boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: .usesDeviceMetrics
        )
    }

    /// Draws the line with its glyphs centered on `centerX` and its baseline at `baseline`.
    func draw(centerX: CGFloat, baseline: CGFloat) {
        text.draw(
            with: NSRect(x: centerX - ink.midX, y: baseline, width: size.width * 2, height: size.height),
            options: []
        )
    }
}

// MARK: - Device frames

func cgImage(of image: NSImage) -> CGImage {
    image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

/// A plain device in black, drawn rather than imaged, with the capture on its screen.
func drawDevice(_ device: Device, raw: NSImage, in rect: NSRect) {
    let ctx = NSGraphicsContext.current!.cgContext
    let bezel = rect.width * device.bezel
    let outerRadius = rect.width * device.cornerRadius

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 80
    shadow.shadowOffset = NSSize(width: 0, height: -30)
    shadow.set()
    color(0x1C1C1E).setFill()
    NSBezierPath(roundedRect: rect, xRadius: outerRadius, yRadius: outerRadius).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // A lighter edge, as the band catches the light.
    let rim = NSBezierPath(
        roundedRect: rect.insetBy(dx: 3, dy: 3), xRadius: outerRadius - 3, yRadius: outerRadius - 3
    )
    rim.lineWidth = 6
    color(0x6E6E73).setStroke()
    rim.stroke()

    let screenRect = rect.insetBy(dx: bezel, dy: bezel)
    let screenRadius = max(outerRadius - bezel, 0)
    ctx.saveGState()
    NSBezierPath(roundedRect: screenRect, xRadius: screenRadius, yRadius: screenRadius).addClip()
    ctx.draw(cgImage(of: raw), in: screenRect)
    ctx.restoreGState()
}

// MARK: - Composition

func compose(_ shot: Screenshot, language: String, device: Device) -> Bool {
    guard let copy = shot.copy[device]?[language] else { return true }
    let rawURL = device.rawDir(language).appendingPathComponent("\(shot.name).png")
    guard let raw = NSImage(contentsOf: rawURL), let rawRep = raw.representations.first else {
        print("missing raw capture: \(rawURL.path)")
        return false
    }

    let canvasSize = device.canvasSize
    let s = device.scale
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    NSGradient(starting: gradientTop, ending: gradientBottom)?
        .draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

    // Two centered lines in a band at the top. AppKit's origin is bottom-left.
    let margin = 96 * s
    let textWidth = canvasSize.width - 2 * margin
    // Scaled up less than the rest on iPad, so the device keeps its room.
    let textSize = 104 * min(s, 1.25)
    let header = Line(copy.header, size: textSize, bold: true, maxWidth: textWidth)
    let caption = Line(copy.caption, size: textSize, bold: false, maxWidth: textWidth)
    let baselineGap = header.size.height
    // From the top of the header's glyphs to the bottom of the caption's.
    let inkHeight = header.ink.maxY + baselineGap - caption.ink.minY

    let screenAspect = CGFloat(rawRep.pixelsWide) / CGFloat(rawRep.pixelsHigh)
    let screenHeightPerWidth = (1 - 2 * device.bezel) / screenAspect
    let aspect = 1 / (screenHeightPerWidth + 2 * device.bezel)
    let deviceTop = canvasSize.height - inkHeight - 2 * 120 * s
    var deviceSize: NSSize
    let deviceBottom: CGFloat
    switch device {
    case .iPhone:
        // The whole device sits below the text band, centered in the space that is left.
        let availableHeight = deviceTop - 120 * s
        deviceSize = NSSize(width: availableHeight * aspect, height: availableHeight)
        if deviceSize.width > canvasSize.width - 2 * margin {
            deviceSize.width = canvasSize.width - 2 * margin
            deviceSize.height = deviceSize.width / aspect
        }
        deviceBottom = deviceTop - (availableHeight + deviceSize.height) / 2
    case .iPad:
        // The iPad is as wide as the margins allow, hangs from the text band, and runs a
        // little off the bottom of the canvas.
        deviceSize = NSSize(width: canvasSize.width - 2 * margin, height: (canvasSize.width - 2 * margin) / aspect)
        deviceBottom = deviceTop - deviceSize.height
    }
    let deviceRect = NSRect(
        x: ((canvasSize.width - deviceSize.width) / 2).rounded(),
        y: deviceBottom.rounded(),
        width: deviceSize.width,
        height: deviceSize.height
    )

    // The text's glyphs are centered between the top of the canvas and the device.
    let inkTop = (canvasSize.height + deviceRect.maxY + inkHeight) / 2
    let headerBaseline = (inkTop - header.ink.maxY).rounded()
    header.draw(centerX: canvasSize.width / 2, baseline: headerBaseline)
    caption.draw(centerX: canvasSize.width / 2, baseline: headerBaseline - baselineGap)

    drawDevice(device, raw: raw, in: deviceRect)

    image.unlockFocus()

    // Rasterize at exactly the canvas size in pixels, without alpha, as App Store Connect wants.
    // AppKit cannot draw into a bitmap without alpha, so this goes through Core Graphics.
    guard let context = CGContext(
        data: nil, width: Int(canvasSize.width), height: Int(canvasSize.height),
        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return false }
    var rect = NSRect(origin: .zero, size: canvasSize)
    context.draw(image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!, in: rect)
    guard let flattened = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: flattened).representation(using: .png, properties: [:])
    else { return false }
    let outDir = device.outDir(language)
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let outURL = outDir.appendingPathComponent("\(shot.name).png")
    do {
        try png.write(to: outURL)
        print("wrote \(outURL.path.replacingOccurrences(of: scriptDir.path + "/", with: ""))")
        return true
    } catch {
        print("failed to write \(outURL.path): \(error)")
        return false
    }
}

var allOK = true
for language in languages {
    for device in [Device.iPhone, .iPad] {
        for shot in screenshots {
            allOK = compose(shot, language: language, device: device) && allOK
        }
    }
}
exit(allOK ? 0 : 1)
