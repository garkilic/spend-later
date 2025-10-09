import SwiftUI
import Photos

struct AppRootView: View {
    enum Tab: Hashable {
        case dashboard
        case add
        case history
        case reward
    }

    let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var addItemViewModel: AddItemViewModel
    @StateObject private var passcodeViewModel: PasscodeViewModel
    @State private var historyViewModel: HistoryViewModel?
    @State private var rewardViewModel: TestViewModel?
    @State private var settingsViewModel: SettingsViewModel?

    @State private var selectedTab: Tab = .dashboard
    @State private var lastNonAddTab: Tab = .dashboard
    @State private var isLocked = false
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    @State private var hasCheckedOnboarding = false
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false

    init(container: AppContainer) {
        self.container = container

        // Initialize core ViewModels needed immediately
        // Others (History, Reward, Settings) are lazy-loaded on-demand
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(
            itemRepository: container.itemRepository,
            monthRepository: container.monthRepository,
            settingsRepository: container.settingsRepository,
            imageStore: container.imageStore))

        _addItemViewModel = StateObject(wrappedValue: AddItemViewModel(
            itemRepository: container.itemRepository))

        _passcodeViewModel = StateObject(wrappedValue: PasscodeViewModel(
            passcodeManager: container.passcodeManager,
            settingsRepository: container.settingsRepository))
    }

    var body: some View {
        ZStack {
            Color.surfaceFallback.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                DashboardView(viewModel: dashboardViewModel,
                          addItemViewModel: addItemViewModel,
                          onOpenSettings: { showingSettings = true },
                          makeDetailViewModel: { item in
                              ItemDetailViewModel(item: item,
                                                  itemRepository: container.itemRepository,
                                                  settingsRepository: container.settingsRepository)
                          })
                .tabItem { Label("Dashboard", systemImage: "house") }
                .tag(Tab.dashboard)

            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(Tab.add)

            if let historyVM = historyViewModel {
                HistoryView(viewModel: historyVM,
                            makeDetailViewModel: { item in
                                ItemDetailViewModel(item: item,
                                                    itemRepository: container.itemRepository,
                                                    settingsRepository: container.settingsRepository)
                            },
                            onItemDeleted: { _ in
                                dashboardViewModel.refresh()
                            })
                    .tabItem { Label("History", systemImage: "clock") }
                    .tag(Tab.history)
            } else {
                Color.clear
                    .tabItem { Label("History", systemImage: "clock") }
                    .tag(Tab.history)
            }

            if let rewardVM = rewardViewModel {
                TestView(viewModel: rewardVM) { item in
                    container.imageStore.loadImage(named: item.imagePath)
                }
                    .tabItem { Label("Spin", systemImage: "sparkles") }
                    .tag(Tab.reward)
            } else {
                Color.clear
                    .tabItem { Label("Spin", systemImage: "sparkles") }
                    .tag(Tab.reward)
            }
            }

            // Splash screen overlay (only on first launch)
            if !hasLaunchedBefore {
                splashScreen
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .add {
                DispatchQueue.main.async {
                    showingAddSheet = true
                    selectedTab = lastNonAddTab
                }
            } else {
                lastNonAddTab = newValue

                // Lazy load ViewModels and data when first accessed
                switch newValue {
                case .history:
                    if historyViewModel == nil {
                        historyViewModel = HistoryViewModel(
                            monthRepository: container.monthRepository,
                            itemRepository: container.itemRepository,
                            imageStore: container.imageStore,
                            settingsRepository: container.settingsRepository)
                    }
                    historyViewModel?.refresh()
                case .reward:
                    if rewardViewModel == nil {
                        rewardViewModel = TestViewModel(
                            itemRepository: container.itemRepository,
                            monthRepository: container.monthRepository,
                            settingsRepository: container.settingsRepository,
                            imageStore: container.imageStore,
                            haptics: container.hapticManager)
                    }
                    rewardViewModel?.refresh()
                default:
                    break
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            if let settingsVM = settingsViewModel {
                NavigationStack {
                    SettingsView(viewModel: settingsVM)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddItemSheet(viewModel: addItemViewModel)
        }
        .onChange(of: showingSettings) { _, isShowing in
            if isShowing && settingsViewModel == nil {
                settingsViewModel = SettingsViewModel(
                    settingsRepository: container.settingsRepository,
                    passcodeManager: container.passcodeManager)
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $isLocked) {
            PasscodeLockView(viewModel: passcodeViewModel) {
                isLocked = false
            }
        }
        .task {
            // On first launch, delay to show launch screen longer
            if !hasLaunchedBefore {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.3)) {
                    hasLaunchedBefore = true
                }
            }

            // Check onboarding first (synchronous, fast)
            if !hasCheckedOnboarding {
                hasCheckedOnboarding = true
                if !hasCompletedOnboarding {
                    showingOnboarding = true
                    return
                }
            }

            // Load lock state synchronously (it's fast, just reads UserDefaults)
            do {
                let settings = try container.settingsRepository.loadAppSettings()
                passcodeViewModel.reset()
                if settings.passcodeEnabled {
                    passcodeViewModel.load()
                    isLocked = true
                } else {
                    isLocked = false
                }
            } catch {
                isLocked = false
            }

            // Only load dashboard data if not locked
            if hasCompletedOnboarding && !isLocked {
                dashboardViewModel.refresh()
            }

            // Defer non-critical background work to avoid blocking UI
            Task.detached(priority: .background) {
                // Wait 1 second to let UI settle
                try? await Task.sleep(for: .seconds(1))

                // Check for pending closeout but don't auto-show
                // User must click button on Reward tab

                // Preload PhotoPicker framework for Record Impulse (low priority)
                try? await Task.sleep(for: .seconds(2))
                _ = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }

            // Return to dashboard when app becomes active
            selectedTab = .dashboard

            // Refresh lock state and dashboard data
            refreshLockState()
            if !isLocked {
                dashboardViewModel.refresh()
            }

            // Rollover check handled by Reward tab button
        }
        .onChange(of: isLocked) { _, newValue in
            // Return to dashboard after unlocking
            if !newValue {
                selectedTab = .dashboard

                // Only refresh dashboard after unlocking
                dashboardViewModel.refresh()
            }
        }
    }
}

private extension AppRootView {
    var splashScreen: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image("LaunchIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)

                Text("Resist. Save.\nWin. Repeat.")
                    .font(.system(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
            }
        }
    }

    func refreshLockState() {
        do {
            let settings = try container.settingsRepository.loadAppSettings()
            passcodeViewModel.reset()
            if settings.passcodeEnabled {
                passcodeViewModel.load()
                isLocked = true
            } else {
                isLocked = false
            }
        } catch {
            isLocked = false
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    AppRootView(container: PreviewSupport.container)
}
#endif
