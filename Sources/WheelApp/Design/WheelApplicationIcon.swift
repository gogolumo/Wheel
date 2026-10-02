import AppKit
import SwiftUI
import WheelMacOS

/// Icons come only from the local application bundle. Missing targets have a symbol.
struct WheelApplicationIcon: View {
    let application: WheelApplicationContext
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let url = application.applicationURL {
                Image(nsImage: WheelApplicationIconCache.shared.icon(at: url))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.15)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Avoid repeated Workspace icon requests while the pointer changes selection.
@MainActor
private final class WheelApplicationIconCache {
    static let shared = WheelApplicationIconCache()
    private let icons = NSCache<NSURL, NSImage>()

    private init() {
        icons.countLimit = 64
    }

    func icon(at url: URL) -> NSImage {
        let key = url as NSURL
        if let icon = icons.object(forKey: key) {
            return icon
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons.setObject(icon, forKey: key)
        return icon
    }
}
