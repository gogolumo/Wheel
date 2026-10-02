import AppKit

/// Explicit packaging proof; invoked before any native input or application capture.
@MainActor
enum WheelBrandAudit {
    static func isRequested(_ arguments: [String]) -> Bool {
        arguments.contains("--verify-brand-resources")
    }

    static func verify() throws {
        guard let bundle = WheelBrand.resourceBundle() else {
            throw AuditError.missingBundle
        }
        if Bundle.main.bundleIdentifier == "dev.gogolumo.Wheel" {
            guard let resources = Bundle.main.resourceURL else {
                throw AuditError.missingBundle
            }
            let expected = resources.appendingPathComponent("Wheel_WheelApp.bundle")
                .resolvingSymlinksInPath().standardizedFileURL
            guard bundle.bundleURL.resolvingSymlinksInPath().standardizedFileURL == expected,
                  expected.path.hasPrefix(
                    Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL.path + "/"
                  )
            else {
                throw AuditError.externalResources
            }
        }

        for name in [
            "WheelSymbol", "WheelSymbolLight", "WheelSymbolMonochromeBlack",
            "WheelSymbolMonochromeWhite", "WheelMenuBarTemplate"
        ] {
            guard let url = bundle.url(forResource: name, withExtension: "pdf"),
                  let image = NSImage(contentsOf: url), image.isValid
            else {
                throw AuditError.invalidImage(name)
            }
        }
        guard let icon = WheelBrand.appIcon, icon.isValid,
              WheelBrand.menuBarTemplateImage.isTemplate,
              WheelBrand.menuBarTemplateImage.size == NSSize(width: 18, height: 18)
        else {
            throw AuditError.invalidImage("app icon or menu template")
        }
        print("Wheel brand resource audit PASS: \(bundle.bundleURL.path)")
    }

    private enum AuditError: LocalizedError {
        case missingBundle, externalResources, invalidImage(String)

        var errorDescription: String? {
            switch self {
            case .missingBundle: return "The Wheel brand resource bundle is missing."
            case .externalResources: return "Packaged Wheel resources must resolve inside the application."
            case let .invalidImage(name): return "The Wheel brand image could not be decoded: \(name)."
            }
        }
    }
}
