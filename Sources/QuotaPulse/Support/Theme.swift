import SwiftUI

enum AppColors {
    static let backgroundStart = Color.white
    static let backgroundMiddle = Color(red: 0.97, green: 0.97, blue: 1.00)
    static let backgroundEnd = Color(red: 0.93, green: 0.97, blue: 1.00)

    static let primaryText = Color(red: 0.125, green: 0.129, blue: 0.153)
    static let strongText = Color(red: 0.09, green: 0.094, blue: 0.169)
    static let secondaryText = Color(red: 0.384, green: 0.396, blue: 0.447)
    static let tertiaryText = Color(red: 0.541, green: 0.553, blue: 0.596)
    static let topValue = Color(red: 0.145, green: 0.133, blue: 0.451)

    static let accentBlue = Color(red: 0.086, green: 0.549, blue: 1.00)
    static let accentIndigo = Color(red: 0.204, green: 0.420, blue: 1.00)
    static let accentPurple = Color(red: 0.463, green: 0.341, blue: 0.969)

    static let healthy = Color(red: 0.090, green: 0.780, blue: 0.710)
    static let stable = Color(red: 0.224, green: 0.788, blue: 0.541)
    static let track = Color(red: 0.906, green: 0.925, blue: 0.961)
    static let divider = Color(red: 0.275, green: 0.314, blue: 0.431).opacity(0.08)
    static let glassFill = Color.white.opacity(0.76)
    static let glassStroke = Color.white.opacity(0.72)
}

extension QuotaHealth {
    var progressColor: Color {
        switch self {
        case .healthy: AppColors.accentIndigo
        case .warning: Color(red: 0.96, green: 0.61, blue: 0.13)
        case .critical: Color(red: 0.96, green: 0.29, blue: 0.25)
        case .unknown: AppColors.tertiaryText
        }
    }

    var backgroundColors: [Color] {
        return switch self {
        case .healthy: [AppColors.backgroundStart, AppColors.backgroundMiddle, AppColors.backgroundEnd]
        case .warning: [Color(red: 0.98, green: 0.98, blue: 1.00), Color(red: 0.98, green: 0.97, blue: 1.00), Color(red: 0.94, green: 0.97, blue: 1.00)]
        case .critical: [Color(red: 1.00, green: 0.97, blue: 0.98), Color(red: 0.98, green: 0.95, blue: 1.00), Color(red: 0.94, green: 0.96, blue: 1.00)]
        case .unknown: [Color.white.opacity(0.20), AppColors.backgroundMiddle.opacity(0.18)]
        }
    }

    var shadowColor: Color { Color(red: 0.18, green: 0.28, blue: 0.48).opacity(0.14) }
    var color: Color {
        switch self {
        case .healthy: AppColors.healthy
        case .warning: .orange
        case .critical: .red
        case .unknown: AppColors.tertiaryText
        }
    }

    var foregroundColor: Color {
        switch self {
        case .healthy: AppColors.primaryText
        case .warning: .orange
        case .critical: .red
        case .unknown: AppColors.secondaryText
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .healthy: LinearGradient(colors: [AppColors.accentBlue, AppColors.accentIndigo, AppColors.accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warning: LinearGradient(colors: [Color(red: 0.28, green: 0.16, blue: 0.04), Color(red: 0.12, green: 0.08, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .critical: LinearGradient(colors: [Color(red: 0.30, green: 0.06, blue: 0.09), Color(red: 0.13, green: 0.04, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unknown: LinearGradient(colors: [Color(red: 0.13, green: 0.14, blue: 0.17), Color(red: 0.07, green: 0.08, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

extension ProviderUsage {
    var accent: Color { providerId.lowercased() == "claude" ? Color(red: 0.88, green: 0.36, blue: 0.28) : AppColors.accentIndigo }

    var softPalette: [Color] {
        let health = QuotaHealth(remaining: [session?.remainingPercent, weekly?.remainingPercent].compactMap { $0 }.min())
        switch health {
        case .warning:
            return [Color(red: 0.98, green: 0.98, blue: 1.00), Color(red: 0.94, green: 0.96, blue: 1.00)]
        case .critical:
            return [Color(red: 1.00, green: 0.97, blue: 0.99), Color(red: 0.95, green: 0.94, blue: 1.00)]
        default:
            return providerId.lowercased() == "claude"
                ? [Color(red: 1.00, green: 0.97, blue: 0.96), Color(red: 0.96, green: 0.94, blue: 1.00)]
                : [Color(red: 0.94, green: 0.98, blue: 1.00), Color(red: 0.91, green: 0.95, blue: 1.00)]
        }
    }
}

extension WeatherMood {
    func atmosphericColors(isDay: Bool) -> [Color] {
        if !isDay {
            return switch self {
            case .clear:
                [Color(red: 0.08, green: 0.16, blue: 0.30), Color(red: 0.14, green: 0.25, blue: 0.43), Color(red: 0.24, green: 0.31, blue: 0.47)]
            case .partlyCloudy:
                [Color(red: 0.12, green: 0.20, blue: 0.33), Color(red: 0.22, green: 0.30, blue: 0.42), Color(red: 0.28, green: 0.35, blue: 0.46)]
            case .cloudy, .fog:
                [Color(red: 0.17, green: 0.23, blue: 0.31), Color(red: 0.30, green: 0.36, blue: 0.44), Color(red: 0.24, green: 0.30, blue: 0.38)]
            case .rain, .storm:
                [Color(red: 0.08, green: 0.15, blue: 0.24), Color(red: 0.20, green: 0.28, blue: 0.37), Color(red: 0.13, green: 0.21, blue: 0.31)]
            case .snow:
                [Color(red: 0.22, green: 0.31, blue: 0.42), Color(red: 0.43, green: 0.52, blue: 0.61), Color(red: 0.31, green: 0.40, blue: 0.50)]
            }
        }
        return switch self {
        case .clear:
            [Color(red: 0.94, green: 0.97, blue: 1.00), Color(red: 0.97, green: 0.96, blue: 1.00), Color(red: 0.92, green: 0.96, blue: 1.00)]
        case .partlyCloudy:
            [Color(red: 0.94, green: 0.97, blue: 1.00), Color(red: 0.91, green: 0.95, blue: 1.00), Color(red: 0.95, green: 0.96, blue: 1.00)]
        case .cloudy:
            [Color(red: 0.91, green: 0.95, blue: 1.00), Color(red: 0.87, green: 0.92, blue: 0.98), Color(red: 0.93, green: 0.95, blue: 1.00)]
        case .fog:
            [Color(red: 0.94, green: 0.96, blue: 1.00), Color(red: 0.90, green: 0.94, blue: 0.98), Color(red: 0.95, green: 0.96, blue: 1.00)]
        case .rain:
            [Color(red: 0.86, green: 0.92, blue: 0.99), Color(red: 0.82, green: 0.89, blue: 0.97), Color(red: 0.89, green: 0.94, blue: 1.00)]
        case .storm:
            [Color(red: 0.78, green: 0.86, blue: 0.96), Color(red: 0.74, green: 0.83, blue: 0.94), Color(red: 0.84, green: 0.90, blue: 0.98)]
        case .snow:
            [Color(red: 0.94, green: 0.98, blue: 1.00), Color.white, Color(red: 0.90, green: 0.96, blue: 1.00)]
        }
    }
}

extension View {
    @ViewBuilder
    func quotaLiquidGlass(cornerRadius: CGFloat) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
#else
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        self
            .background {
                ZStack {
                    shape.fill(.thinMaterial)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.82),
                                AppColors.glassFill,
                                Color(red: 0.96, green: 0.98, blue: 1.00).opacity(0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                    colors: [
                        AppColors.glassStroke,
                        Color(red: 0.88, green: 0.91, blue: 0.98).opacity(0.18),
                        Color(red: 0.95, green: 0.98, blue: 1.00).opacity(0.56)
                    ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            }
#endif
    }

    @ViewBuilder
    func quotaCompactGlass(cornerRadius: CGFloat) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
#else
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        self
            .background {
                ZStack {
                    shape.fill(.thinMaterial)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.84),
                                Color.white.opacity(0.76),
                                Color(red: 0.96, green: 0.98, blue: 1.00).opacity(0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color(red: 0.95, green: 0.98, blue: 1.00).opacity(0.72),
                    lineWidth: 0.7
                )
            }
#endif
    }
}
