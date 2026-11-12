import SwiftUI
import UIKit

enum AppFont {
    /// Headings/titles use `.title` as their Dynamic Type reference: the
    /// literal `size` passed in is the point size at the system's default
    /// (`.large`) content size category, and it scales up/down from there
    /// as the user changes their preferred Text Size in Settings.
    ///
    /// Uses the system serif design at a bold weight as a stand-in for
    /// Fraunces (not bundled in this app, and no network access here to
    /// fetch it) -- a bold system serif reads close to Fraunces's chunky,
    /// high-contrast display look.
    static func display(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title) -> Font {
        scaledSystemFont(size: size, weight: .bold, design: .serif, relativeTo: textStyle)
    }

    /// Body/caption-weight text uses `.body` as its Dynamic Type reference
    /// by default, same scaling behavior as `display(_:relativeTo:)` above.
    ///
    /// Uses the system rounded design as a stand-in for Nunito, for the
    /// same reason as `display` above -- rounded system text has a similarly
    /// friendly, soft feel.
    static func body(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        scaledSystemFont(size: size, weight: .regular, design: .rounded, relativeTo: textStyle)
    }

    /// Bold rounded weight, for tag chips and other small emphasized labels
    /// that were `font-bold` in the reference design.
    static func bodyBold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        scaledSystemFont(size: size, weight: .bold, design: .rounded, relativeTo: textStyle)
    }

    /// Semibold rounded weight, for medium-emphasis labels between `body`
    /// and `bodyBold`.
    static func bodySemibold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        scaledSystemFont(size: size, weight: .semibold, design: .rounded, relativeTo: textStyle)
    }

    static func bodyItalic(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        scaledSystemFont(size: size, weight: .regular, design: .rounded, relativeTo: textStyle).italic()
    }

    /// System fonts created via `Font.system(size:weight:design:)` don't
    /// automatically scale with Dynamic Type the way `.custom(_:size:relativeTo:)`
    /// does, so this builds the equivalent `UIFont` by hand and runs it
    /// through `UIFontMetrics` to get the same auto-scaling behavior the
    /// bundled-font versions of these helpers had.
    private static func scaledSystemFont(
        size: CGFloat,
        weight: UIFont.Weight,
        design: UIFontDescriptor.SystemDesign,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(design) ?? base.fontDescriptor
        let designed = UIFont(descriptor: descriptor, size: size)
        let scaled = UIFontMetrics(forTextStyle: textStyle.uiKitTextStyle).scaledFont(for: designed)
        return Font(scaled)
    }
}

private extension Font.TextStyle {
    var uiKitTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}
