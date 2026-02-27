import Foundation
import SwiftUI

struct ArrowStyle: Codable, Equatable {
    var thickness: Double
    var headSize: Double
    var isDashed: Bool
    var dashLength: Double
    var color: CodableColor

    init(
        thickness: Double = 3,
        headSize: Double = 12,
        isDashed: Bool = false,
        dashLength: Double = 8,
        color: CodableColor = CodableColor(red: 1, green: 0.6, blue: 0, alpha: 1)
    ) {
        self.thickness = thickness
        self.headSize = headSize
        self.isDashed = isDashed
        self.dashLength = dashLength
        self.color = color
    }

    static let `default` = ArrowStyle()
    static let thick = ArrowStyle(thickness: 5, headSize: 16)
    static let dashed = ArrowStyle(isDashed: true, dashLength: 10)
    static let red = ArrowStyle(color: CodableColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
    static let white = ArrowStyle(color: CodableColor(red: 1, green: 1, blue: 1, alpha: 1))
}
