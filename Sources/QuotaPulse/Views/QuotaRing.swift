import SwiftUI

struct QuotaRing: View {
    let title: String
    let remaining: Double?
    let resetAt: Date?
    var expanded = false
    let language: LanguageSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress = 0.0

    private var health: QuotaHealth { QuotaHealth(remaining: remaining) }
    private var accent: Color { health.progressColor }

    var body: some View {
        Group {
            if expanded {
                HStack(spacing: 17) {
                    dial(size: 78)
                    details(alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    dial(size: 67)
                    details(alignment: .center)
                }
            }
        }
        .onAppear {
            if reduceMotion { animatedProgress = remaining ?? 0 }
            else { withAnimation(.smooth(duration: 0.7).delay(0.06)) { animatedProgress = remaining ?? 0 } }
        }
        .onChange(of: remaining) { _, value in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { animatedProgress = value ?? 0 }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: health)
    }

    private func dial(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(AppColors.track, lineWidth: 7)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [AppColors.accentBlue, AppColors.accentIndigo, AppColors.accentPurple, AppColors.accentBlue],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.accentIndigo.opacity(0.22), radius: 10)
            Circle()
                .stroke(AppColors.glassStroke.opacity(0.72), lineWidth: 0.7)
                .padding(5)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(percentNumber)
                    .font(.system(size: expanded ? 24 : 20, weight: .semibold, design: .rounded))
                Text("%")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .monospacedDigit()
            .foregroundStyle(AppColors.strongText)
            .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.52), in: Circle())
    }

    private func details(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.primaryText)
            Text(usageCopy)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
            Label(
                resetAt.map {
                    language.text(
                        "quota.resets",
                        QuotaFormatters.reset(language: language.language).string(from: $0)
                    )
                } ?? language.text("quota.resetWaiting"),
                systemImage: "clock"
            )
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: expanded ? .infinity : nil, alignment: expanded ? .leading : .center)
    }

    private var percentNumber: String {
        guard let remaining else { return "--" }
        return String(Int((remaining * 100).rounded()))
    }

    private var usageCopy: String {
        guard let remaining else { return language.text("quota.syncing") }
        return language.text("quota.used", Int(((1 - remaining) * 100).rounded()))
    }
}
