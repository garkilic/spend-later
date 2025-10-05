import SwiftUI

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
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(settingsRepository: container.settingsRepository, notificationScheduler: container.notificationScheduler, passcodeManager: container.passcodeManager))
        _passcodeViewModel = StateObject(wrappedValue: PasscodeViewModel(passcodeManager: container.passcodeManager, settingsRepository: container.settingsRepository))
    }

    var body: some View {
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
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .add {
                DispatchQueue.main.async {
                    showingAddSheet = true
                    selectedTab = lastNonAddTab
                }
            } else {
                lastNonAddTab = newValue
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
        .onChange(of: showingAddSheet) { _, isPresented in
            if !isPresented {
                // Refresh history when add sheet is dismissed
                historyViewModel.refresh()
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
        .onAppear {
            dashboardViewModel.refresh()
            historyViewModel.refresh()
            rewardViewModel.refresh()
            settingsViewModel.load()

            // Delay onboarding check to ensure it appears on top of everything
            if !hasCheckedOnboarding {
                hasCheckedOnboarding = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !hasCompletedOnboarding {
                        showingOnboarding = true
                    }
                }
            }

            Task { await checkRollover() }
            Task { await refreshLockState() }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                // Always return to dashboard when app becomes active
                selectedTab = .dashboard
                Task {
                    await checkRollover()
                    await refreshLockState()
                }
            }
        }
        .onChange(of: isLocked) { _, newValue in
            // Return to dashboard after unlocking
            if !newValue {
                selectedTab = .dashboard
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
