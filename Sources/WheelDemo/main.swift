import Foundation
import WheelDomain

func entry(_ name: String) -> ContextEntry {
    ContextEntry(
        applicationBundleID: "dev.wheel.demo",
        contextToken: name,
        capturedAt: Date(timeIntervalSince1970: 0)
    )
}

func trail(_ history: ContextHistory) -> String {
    history.entries.enumerated().map { index, entry in
        let label = entry.contextToken ?? "?"
        return index == history.currentPosition ? "[\(label)]" : label
    }.joined(separator: " → ")
}

var history = ContextHistory()
let a = entry("A")
let b = entry("B")
let c = entry("C")
let d = entry("D")

history.recordIndependent(a)
history.recordIndependent(b)
history.recordIndependent(c)

print("start:       \(trail(history))")

if let target = history.target(for: .left) {
    history.commitNavigation(
        direction: .left,
        targetID: target.id,
        result: RestorationResult(status: .success, depth: .window)
    )
}
print("LEFT:        \(trail(history))")

if let target = history.target(for: .right) {
    history.commitNavigation(
        direction: .right,
        targetID: target.id,
        result: RestorationResult(status: .success, depth: .window)
    )
}
print("RIGHT:       \(trail(history))")

if let target = history.target(for: .left) {
    history.commitNavigation(
        direction: .left,
        targetID: target.id,
        result: RestorationResult(status: .partial, depth: .application)
    )
}
print("LEFT again:  \(trail(history))")

history.recordIndependent(d)
print("new D:       \(trail(history))")
