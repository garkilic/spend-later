import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient with subtle accent glow
                LinearGradient(
                    colors: onboardingBackgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Skip button
                    HStack {
                        Spacer()
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)
                    }
                    .frame(height: 44)

                    // Page content
                    TabView(selection: $currentPage) {
                        page1.tag(0)
                        page2.tag(1)
                        page3.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .frame(height: geometry.size.height - 140)

                    // Bottom button
                    Button {
                        if currentPage < 2 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < 2 ? "Next" : "Get Started")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.accentFallback)
                            .foregroundColor(Color.onAccentFallback)
                            .cornerRadius(CornerRadius.button)
                    }
                    .padding(.horizontal, Spacing.sideGutter)
                    .padding(.bottom, Spacing.xl)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func completeOnboarding() {
        HapticManager.shared.success()
        onComplete()
        dismiss()
    }
}

private extension OnboardingView {
    var onboardingBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black,
                Color.accentFallback.opacity(0.5)
            ]
        } else {
            return [
                Color.surfaceFallback,
                Color.accentFallback.opacity(0.25)
            ]
        }
    }

    var page1: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            stepLabel(1)

            // App Icon
            if let _ = UIImage(named: "LaunchIcon") {
                Image("LaunchIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(CornerRadius.card)
                    .padding(.bottom, Spacing.lg)
            } else {
                // Fallback icon if LaunchIcon doesn't exist
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(Color.appAccent)
                        .frame(width: 120, height: 120)

                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.onAccentFallback)
                }
                .padding(.bottom, Spacing.lg)
            }

            // Title
            Text("See your savings stack up")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Description
            Text("Skip something tempting? Log it here. Every impulse you resist adds to a running total so you can see your willpower in dollars.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var page2: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            stepLabel(2)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color.appAccent)
            }
            .padding(.bottom, Spacing.lg)

            // Title
            Text("Log the impulse in seconds")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Description
            Text("Tap Record Impulse, add the price, drop in a link or photo, and jot a quick note. The more context you capture, the easier it is to stick the landing later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var page3: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            stepLabel(3)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "gift.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.orange)
            }
            .padding(.bottom, Spacing.lg)

            // Title
            Text("Reward yourself once a month")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Description
            Text("When the month wraps, we’ll remind you to choose one item you logged and actually buy it. One treat, guilt-free. Everything else stays in savings—proof your discipline is working.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func stepLabel(_ number: Int) -> some View {
        Text("Step \(number) of 3")
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(Color.secondaryFallback)
            .tracking(0.8)
    }
}

#if DEBUG
#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
#endif
