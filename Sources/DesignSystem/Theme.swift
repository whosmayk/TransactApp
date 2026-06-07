import SwiftUI

public enum AppColor {
    public static let base       = Color(red: 0.047, green: 0.055, blue: 0.063)
    public static let mantle     = Color(red: 0.067, green: 0.075, blue: 0.086)
    public static let surface0   = Color(red: 0.094, green: 0.106, blue: 0.118)
    public static let surface1   = Color(red: 0.122, green: 0.133, blue: 0.149)
    public static let surface2   = Color(red: 0.149, green: 0.165, blue: 0.180)
    public static let overlay0   = Color(red: 0.271, green: 0.290, blue: 0.318)
    public static let subtext0   = Color(red: 0.612, green: 0.627, blue: 0.651)
    public static let subtext1   = Color(red: 0.424, green: 0.439, blue: 0.471)
    public static let text       = Color(red: 0.910, green: 0.918, blue: 0.929)
    public static let accent     = Color(red: 0.424, green: 0.557, blue: 0.749)
    public static let accentDim  = Color(red: 0.290, green: 0.416, blue: 0.588)
    public static let green      = Color(red: 0.420, green: 0.749, blue: 0.541)
    public static let red        = Color(red: 0.831, green: 0.478, blue: 0.478)
    public static let peach      = Color(red: 0.831, green: 0.659, blue: 0.478)
    public static let sapphire   = Color(red: 0.369, green: 0.541, blue: 0.749)
}

public enum AppGradiente {
    public static let accent = LinearGradient(
        colors: [AppColor.accent, AppColor.accentDim],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let surface = LinearGradient(
        colors: [AppColor.surface0, AppColor.mantle],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let cardHeader = LinearGradient(
        colors: [AppColor.accent.opacity(0.12), AppColor.surface0],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let progress = LinearGradient(
        colors: [AppColor.accent, AppColor.sapphire],
        startPoint: .leading,
        endPoint: .trailing
    )
}

public enum TemaEspaciado {
    public static let xs: CGFloat = 4
    public static let s: CGFloat  = 8
    public static let m: CGFloat  = 12
    public static let l: CGFloat  = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum TemaRadio {
    public static let s: CGFloat  = 6
    public static let m: CGFloat  = 10
    public static let l: CGFloat  = 16
    public static let xl: CGFloat = 24
}

public enum Tipografia {
    public static func titulo() -> Font {
        .system(size: 22, weight: .bold, design: .rounded)
    }

    public static func subtitulo() -> Font {
        .system(size: 16, weight: .semibold, design: .rounded)
    }

    public static func cuerpo() -> Font {
        .system(size: 13, weight: .regular)
    }

    public static func montoGrande() -> Font {
        .system(size: 28, weight: .bold, design: .monospaced)
    }

    public static func montoMediano() -> Font {
        .system(size: 18, weight: .semibold, design: .monospaced)
    }
}
