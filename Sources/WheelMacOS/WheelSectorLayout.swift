import Foundation
import WheelDomain

public enum WheelSectorLayout {
    public static func selectedIndex(
        displacement: PointerDisplacement,
        sectorCount: Int,
        minimumDistance: Double
    ) -> Int? {
        guard sectorCount > 0, minimumDistance >= 0 else { return nil }

        let horizontal = displacement.horizontal
        let vertical = displacement.vertical
        let distance = hypot(horizontal, vertical)

        guard distance >= minimumDistance else {
            return nil
        }

        let fullTurn = Double.pi * 2
        let sectorWidth = fullTurn / Double(sectorCount)
        var angle = atan2(vertical, horizontal)

        if angle < 0 {
            angle += fullTurn
        }

        return Int(
            floor((angle + sectorWidth / 2) / sectorWidth)
        ) % sectorCount
    }

    public static func angle(
        for index: Int,
        sectorCount: Int
    ) -> Double {
        guard sectorCount > 0 else { return 0 }

        let normalizedIndex = ((index % sectorCount) + sectorCount) % sectorCount
        return (Double(normalizedIndex) / Double(sectorCount)) * Double.pi * 2
    }
}
