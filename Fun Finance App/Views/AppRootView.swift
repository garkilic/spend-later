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
    @StateObject private var historyViewModel: HistoryViewModel
    @StateObject private var rewardViewModel: TestViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var passcodeViewModel: PasscodeViewModel

    @State private var selectedTab: Tab = .dashboard
    @State private var lastNonAddTab: Tab = .dashboard
    @State private var closeoutSummary: MonthSummaryEntity?
    @State private var isLocked = false
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    @State private var hasCheckedOnboarding = false

    init(container: AppContainer) {
        self.container = container
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(itemRepository: container.itemRepository,
                                                                           monthRepository: container.monthRepository,
                                                                           settingsRepository: container.settingsRepository,
                                                                           imageStore: container.imageStore))
        _addItemViewModel = StateObject(wrappedValue: AddItemViewModel(itemRepository: container.itemRepository))
        _historyViewModel = StateObject(wrappedValue: HistoryViewModel(monthRepository: container.monthRepository,
                                                                      itemRepository: container.itemRepository,
                                                                      imageStore: container.imageStore,
                                                                      settingsRepository: container.settingsRepository))
        _rewardViewModel = StateObject(wrappedValue: TestViewModel(itemRepository: container.itemRepository,
                                                                   monthRepository: container.monthRepository,
                                                                   settingsRepository: container.settingsRepository,
                                                                   imageStore: container.imageStore,
                                                                   haptics: container.hapticManager))
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(settingsRepository: container.settingsRepository, passcodeManager: container.passcodeManager))
        _passcodeViewModel = StateObject(wrappedValue: PasscodeViewModel(passcodeManager: container.passcodeManager, settingsRepository: container.settingsRepository))
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

            HistoryView(viewModel: historyViewModel,
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

            TestView(viewModel: rewardViewModel) { item in
                container.imageStore.loadImage(named: item.imagePath)
            }
                .tabItem { Label("Reward", systemImage: "gift.fill") }
                .tag(Tab.reward)
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

                // Lazy load tab data when first accessed
                switch newValue {
                case .history:
                    historyViewModel.refresh()
                case .reward:
                    rewardViewModel.refresh()
                default:
                    break
                }
            }
        }
        .sheet(item: $closeoutSummary) { summary in
            MonthCloseoutView(viewModel: MonthCloseoutViewModel(summary: summary,
                                                                haptics: container.hapticManager,
                                                                settingsRepository: container.settingsRepository),
                             autoStart: true) { item in
                container.imageStore.loadImage(named: item.imagePath)
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddItemSheet(viewModel: addItemViewModel)
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
            // Check onboarding immediately
            if !hasCheckedOnboarding {
                hasCheckedOnboarding = true
                if !hasCompletedOnboarding {
                    showingOnboarding = true
                    return
                }
            }

            // Load in background - UI shows immediately
            await refreshLockState()

            // Only load dashboard if not locked
            if hasCompletedOnboarding && !isLocked {
                dashboardViewModel.refresh()
            }

            // Check rollover
            await checkRollover()

            // Preload PhotoPicker framework in background (for Record Impulse)
            Task.detached(priority: .background) {
                _ = await PHPhotoLibrary.authorizationStatus(for: .readWrite)
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }

            // Return to dashboard when app becomes active
            selectedTab = .dashboard

            Task.detached(priority: .userInitiated) { @MainActor in
                await self.refreshLockState()

                // Only refresh dashboard if not locked
                if !self.isLocked {
                    self.dashboardViewModel.refresh()
                }

                await self.checkRollover()
            }
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
    func checkRollover() async {
        do {
            if let summary = try container.rolloverService.evaluateIfNeeded() {
                closeoutSummary = summary
            }
        } catch {
            // ignore errors for now
        }
    }

    func refreshLockState() async {
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
