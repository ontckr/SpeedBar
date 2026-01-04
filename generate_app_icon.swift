#!/usr/bin/swift

import AppKit
import Foundation

let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

func generateIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22
    
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    let gradient = NSGradient(colors: [
        NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1.0)
    ])!
    
    gradient.draw(in: path, angle: -45)
    
    let innerShadow = NSShadow()
    innerShadow.shadowColor = NSColor.white.withAlphaComponent(0.3)
    innerShadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.02)
    innerShadow.shadowBlurRadius = CGFloat(size) * 0.05
    
    let symbolSize = CGFloat(size) * 0.5
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
    
    if let symbolImage = NSImage(systemSymbolName: "network", accessibilityDescription: nil) {
        let configuredSymbol = symbolImage.withSymbolConfiguration(config)!
        
        let symbolRect = NSRect(
            x: (CGFloat(size) - symbolSize) / 2,
            y: (CGFloat(size) - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )
        
        NSColor.white.setFill()
        configuredSymbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    
    image.unlockFocus()
    
    return image
}

func saveImage(_ image: NSImage, toPath path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("✓ Saved: \(path)")
    } catch {
        print("✗ Failed to save: \(path) - \(error)")
    }
}

print("🎨 Generating SpeedBar App Icons...")
print("")

let outputDir = "SpeedBar/Assets.xcassets/AppIcon.appiconset"

let fileManager = FileManager.default
if !fileManager.fileExists(atPath: outputDir) {
    try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
}

for (name, size) in sizes {
    let icon = generateIcon(size: size)
    let path = "\(outputDir)/\(name).png"
    saveImage(icon, toPath: path)
}

let contentsJson = """
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let contentsPath = "\(outputDir)/Contents.json"
do {
    try contentsJson.write(toFile: contentsPath, atomically: true, encoding: .utf8)
    print("")
    print("✓ Updated: Contents.json")
} catch {
    print("✗ Failed to update Contents.json: \(error)")
}

print("")
print("🎉 Done! App icons generated successfully.")
print("   Rebuild the project in Xcode to see the new icon.")

