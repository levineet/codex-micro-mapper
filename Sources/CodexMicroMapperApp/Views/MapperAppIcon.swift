import AppKit
import SwiftUI

struct MapperAppIcon: View {
    var size: CGFloat = 56

    var body: some View {
        Image(nsImage: Self.image)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    // Decode the largest ICNS representation once so every in-app size uses
    // the original artwork and colors, independent of icon-service variants.
    @MainActor private static let image: NSImage = {
        let url = Bundle.main.url(forResource: "CodexMicroMapping", withExtension: "icns")
            ?? Bundle.module.url(forResource: "CodexMicroMapping", withExtension: "icns", subdirectory: "Resources")
        guard let url, let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        var rect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        guard let bitmap = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            image.isTemplate = false
            return image
        }
        let original = NSImage(cgImage: bitmap, size: NSSize(width: 1024, height: 1024))
        original.isTemplate = false
        return original
    }()
}
