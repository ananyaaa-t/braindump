import SwiftUI
import UIKit

enum AppFont {
    static func display(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title) -> Font {
        scaledSystemFont(size: size, weight: .bold, design: .serif, relativeTo: textStyle)
    }

    static func body(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        scaledSystemFont(size: size, weight: .regular, design: .rounded, relativeTo: textStyle)
    }

    static func bodyBold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        scaledSystemFont(size: size, weight: .bold, design: .rounded, relativeTo: textStyle)
    }

    static func bodySemibold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        scaledSystemFont(size: size, weight: .semibold, design: .rounded, relativeTo: textStyle)
    }

    static func bodyItalic(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        scaledSystemFont(size: size, weight: .regular, design: .rounded, relativeTo: textStyle).italic()
    }

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
