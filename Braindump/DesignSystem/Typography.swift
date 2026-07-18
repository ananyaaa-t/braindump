import SwiftUI
enum AppFont {
    static func display(_ size: CGFloat) -> Font {
        .custom("CormorantGaramond-LightItalic", size: size)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("EBGaramond-Regular", size: size)
    }

    static func bodyItalic(_ size: CGFloat) -> Font {
        .custom("EBGaramond-Italic", size: size)
    }
}
