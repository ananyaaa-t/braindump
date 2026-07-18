import SwiftUI

extension Color {
    static let paper = Color(hex: "#FAF6EE")

    static let butter = Color(hex: "#F6E8C9")
    static let blush = Color(hex: "#ECD8D4")
    static let sage = Color(hex: "#D6DEC7")
    static let sky = Color(hex: "#D3E0E8")
    static let lilac = Color(hex: "#E0D8E9")
    static let clay = Color(hex: "#E7D5CA")
    static let moss = Color(hex: "#C3D3BB")
    static let stone = Color(hex: "#E1DBD0")
    static let rose = Color(hex: "#E8D4D7")
    static let mist = Color(hex: "#D4E2DF")

    static let dune = Color(hex: "#A8998A")
    static let ink = Color(hex: "#453F37")

    static let hairline = Color(hex: "#E4DFD5")

    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func darkerTint(by amount: Double = 0.15) -> Color {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: max(r - amount, 0),
            green: max(g - amount, 0),
            blue: max(b - amount, 0)
        )
    }
}

extension ShapeStyle where Self == Color {
    static var paper: Color { .paper }
    static var butter: Color { .butter }
    static var blush: Color { .blush }
    static var sage: Color { .sage }
    static var sky: Color { .sky }
    static var lilac: Color { .lilac }
    static var clay: Color { .clay }
    static var moss: Color { .moss }
    static var stone: Color { .stone }
    static var rose: Color { .rose }
    static var mist: Color { .mist }
    static var dune: Color { .dune }
    static var ink: Color { .ink }
    static var hairline: Color { .hairline }
}

enum PageColor: String, CaseIterable, Codable, Identifiable {
    case butter
    case blush
    case sage
    case sky
    case lilac
    case clay
    case moss
    case stone
    case rose
    case mist

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .butter: return .butter
        case .blush: return .blush
        case .sage: return .sage
        case .sky: return .sky
        case .lilac: return .lilac
        case .clay: return .clay
        case .moss: return .moss
        case .stone: return .stone
        case .rose: return .rose
        case .mist: return .mist
        }
    }
}
