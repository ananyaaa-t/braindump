import SwiftUI

/// Raw dynamic-provider `UIColor`s, for UIKit code (the rich text editor's
/// `NSAttributedString` attributes, `UITextView.tintColor`) that needs a
/// color guaranteed to resolve correctly against the current trait
/// collection at draw/render time. Converting a SwiftUI `Color` back to
/// `UIColor` outside of a View's body (as `RichTextEditor`/
/// `ParagraphAttributedText` do, since they're plain UIKit/model code, not
/// SwiftUI view bodies) isn't guaranteed to preserve the light/dark
/// adaptive behavior, so UIKit call sites should reference these directly
/// instead of round-tripping through `Color`.
enum AppUIColor {
    static let ink = UIColor.adaptive(light: "#453F37", dark: "#EBDFCE")
    static let dune = UIColor.adaptive(light: "#776F64", dark: "#B8AFA2")
}

extension UIColor {
    /// Builds a `UIColor` whose resolved color switches on
    /// `traitCollection.userInterfaceStyle` — the actual mechanism behind
    /// both `AppUIColor` above and `Color.adaptive(light:dark:)` below.
    static func adaptive(light: String, dark: String) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }

    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// Each pastel keeps its hue but becomes a deeper, more saturated
    /// "jewel tone" in dark mode, rather than a desaturated, darkened
    /// version of the light color -- an earlier pass tried the latter and
    /// it read as muddy/brownish instead of like a deliberate dark palette,
    /// since these pastels start out with fairly low saturation to begin
    /// with. `stone` stays comparatively more neutral/muted than the rest,
    /// matching its subdued role in the light palette. `ink`/`dune`
    /// (text/icon colors) lighten instead, so contrast against the darker
    /// backgrounds holds up.
    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor.adaptive(light: light, dark: dark))
    }

    static let paper = Color.adaptive(light: "#FAF6EE", dark: "#21201D")
    static let surface = Color.adaptive(light: "#FFFDF8", dark: "#2A2824")

    static let butter = Color.adaptive(light: "#FFF0C0", dark: "#4C432C")
    static let blush = Color.adaptive(light: "#FDDDD8", dark: "#4C322C")
    static let sage = Color.adaptive(light: "#DFF0D0", dark: "#3C4C2C")
    static let sky = Color.adaptive(light: "#CBE9FC", dark: "#2C404C")
    static let lilac = Color.adaptive(light: "#E5DCFB", dark: "#3B2C4C")
    static let clay = Color.adaptive(light: "#FBE0CC", dark: "#4C392C")
    static let moss = Color.adaptive(light: "#C9E8CE", dark: "#374C2C")
    static let stone = Color.adaptive(light: "#EDE7DA", dark: "#4C4840")
    static let rose = Color.adaptive(light: "#FBDCE7", dark: "#4C2C31")
    static let mist = Color.adaptive(light: "#D2F2E8", dark: "#2C4C46")

    static let dune = Color(uiColor: AppUIColor.dune)
    static let ink = Color(uiColor: AppUIColor.ink)

    static let hairline = Color.adaptive(light: "#E4DFD5", dark: "#474542")

    /// Terracotta brand accent for the home screen's avatar badge and the
    /// "new note" floating action button, matching the reference design's
    /// warm accent color. Kept constant across light/dark rather than
    /// adaptive since it's a fixed brand color sitting on its own filled
    /// shape (not directly on the paper background), so contrast against
    /// its own white glyph doesn't shift with appearance.
    static let brandAccent = Color(hex: "#D4785A")

    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
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
    static var surface: Color { .surface }
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
    static var brandAccent: Color { .brandAccent }
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

    /// A deeper, more saturated tint of each color's own hue, used as the
    /// title/preview/timestamp text color on home screen note cards so text
    /// reads as "ink on colored paper" instead of the flat neutral `.ink`
    /// used elsewhere -- matching the reference design's per-card tinted
    /// text. Lightened in dark mode for contrast against the darker jewel
    /// tone backgrounds, same approach as the background colors above.
    var textColor: Color {
        switch self {
        case .butter: return .adaptive(light: "#6B5200", dark: "#F5DFA0")
        case .blush: return .adaptive(light: "#6B3A35", dark: "#F5C9C0")
        case .sage: return .adaptive(light: "#3D6B2A", dark: "#C9E8B0")
        case .sky: return .adaptive(light: "#1A4D6E", dark: "#B8E4FF")
        case .lilac: return .adaptive(light: "#4A3470", dark: "#D8C9FF")
        case .clay: return .adaptive(light: "#8A4A20", dark: "#F5C9A0")
        case .moss: return .adaptive(light: "#2D5E4A", dark: "#B0E8C0")
        case .stone: return .adaptive(light: "#5C5346", dark: "#E8DFC9")
        case .rose: return .adaptive(light: "#A03A5C", dark: "#F5B8CE")
        case .mist: return .adaptive(light: "#1F6E5C", dark: "#B0EBD8")
        }
    }
}
