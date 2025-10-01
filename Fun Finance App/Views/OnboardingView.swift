import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.appSurface,
                    Color.appSurfaceElevated
                ],
                startPoint: .top,
                endPoint: .bottom
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
                    .foregroundColor(Color.appSecondary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }

                // Page content
                TabView(selection: $currentPage) {
                    page1.tag(0)
                    page2.tag(1)
                    page3.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Bottom button
                Button {
                    if currentPage < 2 {
                        withAnimation {
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
                        .background(Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(CornerRadius.button)
                }
                .padding(.horizontal, Spacing.sideGutter)
                .padding(.bottom, Spacing.xl)
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
    var page1: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.appSuccess.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appSuccess, Color.appSuccess.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, Spacing.lg)

            // Title
            Text("Build Willpower")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color.appPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text("Track impulse purchases you resist and watch your savings grow")
                .font(.body)
                .foregroundColor(Color.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    var page2: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, Spacing.lg)

            // Title
            Text("Log Every Win")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color.appPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text("Saw something you wanted but didn't buy? Log it. Every \"no\" is money saved")
                .font(.body)
                .foregroundColor(Color.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    var page3: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "gift.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, Spacing.lg)

            // Title
            Text("Monthly Reward")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color.appPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text("At month's end, spin to win one item you resisted. Celebrate your discipline!")
                .font(.body)
                .foregroundColor(Color.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

#if DEBUG
#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
#endif
