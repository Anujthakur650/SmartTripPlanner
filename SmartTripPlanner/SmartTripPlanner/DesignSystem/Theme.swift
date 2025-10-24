import SwiftUI

struct DynamicColor: Equatable {
    let light: Color
    let dark: Color
    
    init(light: Color, dark: Color) {
        self.light = light
        self.dark = dark
    }
    
    func resolved(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }
}

struct Theme {
    struct ColorPalette {
        let primary: DynamicColor
        let onPrimary: DynamicColor
        let accent: DynamicColor
        let onAccent: DynamicColor
        let background: DynamicColor
        let surface: DynamicColor
        let surfaceMuted: DynamicColor
        let surfaceElevated: DynamicColor
        let border: DynamicColor
        let outline: DynamicColor
        let textPrimary: DynamicColor
        let textSecondary: DynamicColor
        let success: DynamicColor
        let onSuccess: DynamicColor
        let warning: DynamicColor
        let onWarning: DynamicColor
        let error: DynamicColor
        let onError: DynamicColor
        let info: DynamicColor
        let onInfo: DynamicColor
    }
    
    struct TypographyScale {
        let largeTitle: Font
        let title: Font
        let title2: Font
        let headline: Font
        let body: Font
        let callout: Font
        let subheadline: Font
        let footnote: Font
        let caption: Font
        let button: Font
    }
    
    struct SpacingScale {
        let xxs: CGFloat
        let xs: CGFloat
        let s: CGFloat
        let m: CGFloat
        let l: CGFloat
        let xl: CGFloat
        let xxl: CGFloat
    }
    
    struct CornerRadiusScale {
        let s: CGFloat
        let m: CGFloat
        let l: CGFloat
        let xl: CGFloat
        let pill: CGFloat
    }
    
    struct ShadowToken {
        let color: DynamicColor
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        let opacity: Double
        
        func color(for scheme: ColorScheme) -> Color {
            color.resolved(for: scheme).opacity(opacity)
        }
    }
    
    struct ShadowScale {
        let none: ShadowToken
        let subtle: ShadowToken
        let resting: ShadowToken
        let raised: ShadowToken
    }
    
    let name: String
    let colors: ColorPalette
    let typography: TypographyScale
    let spacing: SpacingScale
    let radii: CornerRadiusScale
    let shadows: ShadowScale
    
    static let minimalCalm = Theme(
        name: "Minimal Calm",
        colors: .minimalCalm,
        typography: .rounded,
        spacing: .comfortable,
        radii: .soft,
        shadows: .layered
    )
}

extension Theme.ColorPalette {
    static let minimalCalm = Theme.ColorPalette(
        primary: DynamicColor(
            light: Color(red: 55 / 255, green: 120 / 255, blue: 127 / 255),
            dark: Color(red: 119 / 255, green: 210 / 255, blue: 204 / 255)
        ),
        onPrimary: DynamicColor(
            light: .white,
            dark: Color(red: 8 / 255, green: 26 / 255, blue: 31 / 255)
        ),
        accent: DynamicColor(
            light: Color(red: 113 / 255, green: 154 / 255, blue: 174 / 255),
            dark: Color(red: 142 / 255, green: 198 / 255, blue: 219 / 255)
        ),
        onAccent: DynamicColor(light: .white, dark: Color(red: 9 / 255, green: 18 / 255, blue: 23 / 255)),
        background: DynamicColor(
            light: Color(red: 245 / 255, green: 248 / 255, blue: 248 / 255),
            dark: Color(red: 8 / 255, green: 13 / 255, blue: 16 / 255)
        ),
        surface: DynamicColor(
            light: Color(red: 251 / 255, green: 253 / 255, blue: 253 / 255),
            dark: Color(red: 18 / 255, green: 27 / 255, blue: 32 / 255)
        ),
        surfaceMuted: DynamicColor(
            light: Color(red: 232 / 255, green: 240 / 255, blue: 242 / 255),
            dark: Color(red: 27 / 255, green: 36 / 255, blue: 40 / 255)
        ),
        surfaceElevated: DynamicColor(
            light: Color(red: 243 / 255, green: 248 / 255, blue: 249 / 255),
            dark: Color(red: 30 / 255, green: 41 / 255, blue: 46 / 255)
        ),
        border: DynamicColor(
            light: Color(red: 196 / 255, green: 206 / 255, blue: 210 / 255),
            dark: Color(red: 62 / 255, green: 75 / 255, blue: 83 / 255)
        ),
        outline: DynamicColor(
            light: Color(red: 174 / 255, green: 190 / 255, blue: 197 / 255),
            dark: Color(red: 90 / 255, green: 111 / 255, blue: 122 / 255)
        ),
        textPrimary: DynamicColor(
            light: Color(red: 21 / 255, green: 43 / 255, blue: 49 / 255),
            dark: Color(red: 220 / 255, green: 235 / 255, blue: 238 / 255)
        ),
        textSecondary: DynamicColor(
            light: Color(red: 87 / 255, green: 104 / 255, blue: 112 / 255),
            dark: Color(red: 155 / 255, green: 175 / 255, blue: 183 / 255)
        ),
        success: DynamicColor(
            light: Color(red: 66 / 255, green: 132 / 255, blue: 96 / 255),
            dark: Color(red: 108 / 255, green: 195 / 255, blue: 149 / 255)
        ),
        onSuccess: DynamicColor(light: .white, dark: Color(red: 8 / 255, green: 24 / 255, blue: 19 / 255)),
        warning: DynamicColor(
            light: Color(red: 184 / 255, green: 140 / 255, blue: 73 / 255),
            dark: Color(red: 230 / 255, green: 196 / 255, blue: 125 / 255)
        ),
        onWarning: DynamicColor(light: .white, dark: Color(red: 59 / 255, green: 41 / 255, blue: 12 / 255)),
        error: DynamicColor(
            light: Color(red: 176 / 255, green: 78 / 255, blue: 86 / 255),
            dark: Color(red: 230 / 255, green: 152 / 255, blue: 158 / 255)
        ),
        onError: DynamicColor(light: .white, dark: Color(red: 57 / 255, green: 13 / 255, blue: 16 / 255)),
        info: DynamicColor(
            light: Color(red: 86 / 255, green: 129 / 255, blue: 160 / 255),
            dark: Color(red: 130 / 255, green: 180 / 255, blue: 210 / 255)
        ),
        onInfo: DynamicColor(light: .white, dark: Color(red: 6 / 255, green: 20 / 255, blue: 29 / 255))
    )
}

extension Theme.TypographyScale {
    static let rounded = Theme.TypographyScale(
        largeTitle: .system(.largeTitle, design: .rounded).weight(.semibold),
        title: .system(.title, design: .rounded).weight(.semibold),
        title2: .system(.title2, design: .rounded).weight(.semibold),
        headline: .system(.headline, design: .rounded),
        body: .system(.body, design: .rounded),
        callout: .system(.callout, design: .rounded),
        subheadline: .system(.subheadline, design: .rounded),
        footnote: .system(.footnote, design: .rounded),
        caption: .system(.caption, design: .rounded),
        button: .system(.callout, design: .rounded).weight(.semibold)
    )
}

extension Theme.SpacingScale {
    static let comfortable = Theme.SpacingScale(
        xxs: 4,
        xs: 8,
        s: 12,
        m: 16,
        l: 20,
        xl: 24,
        xxl: 32
    )
}

extension Theme.CornerRadiusScale {
    static let soft = Theme.CornerRadiusScale(
        s: 8,
        m: 12,
        l: 16,
        xl: 24,
        pill: 999
    )
}

extension Theme.ShadowScale {
    static let layered = Theme.ShadowScale(
        none: Theme.ShadowToken(
            color: DynamicColor(light: .clear, dark: .clear),
            radius: 0,
            x: 0,
            y: 0,
            opacity: 0
        ),
        subtle: Theme.ShadowToken(
            color: DynamicColor(light: .black.opacity(0.2), dark: .black.opacity(0.4)),
            radius: 8,
            x: 0,
            y: 2,
            opacity: 1
        ),
        resting: Theme.ShadowToken(
            color: DynamicColor(light: .black.opacity(0.16), dark: .black.opacity(0.7)),
            radius: 14,
            x: 0,
            y: 10,
            opacity: 1
        ),
        raised: Theme.ShadowToken(
            color: DynamicColor(light: .black.opacity(0.24), dark: .black.opacity(0.8)),
            radius: 20,
            x: 0,
            y: 16,
            opacity: 1
        )
    )
}

extension View {
    func themedBackground(_ theme: Theme, colorScheme: ColorScheme) -> some View {
        background(theme.colors.background.resolved(for: colorScheme))
    }
}
