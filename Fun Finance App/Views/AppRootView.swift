import SwiftUI

struct AppRootView: View {
    enum Tab: Hashable {
        case dashboard
        case add
        case history
    }

    let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var addItemViewModel: AddItemViewModel
    @StateObject private var historyViewModel: HistoryViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var passcodeViewModel: PasscodeViewModel

    @State private var selectedTab: Tab = .dashboard
    @State private var lastNonAddTab: Tab = .dashboard
    @State private var closeoutSummary: MonthSummaryEntity?
    @State private var isLocked = false
    @State private var showingAddSheet = false
    @State private var showingSettings = false

    init(container: AppContainer) {
        self.container = container
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(itemRepository: container.itemRepository, imageStore: container.imageStore))
        _addItemViewModel = StateObject(wrappedValue: AddItemViewModel(itemRepository: container.itemRepository))
        _historyViewModel = StateObject(wrappedValue: HistoryViewModel(monthRepository: container.monthRepository, itemRepository: container.itemRepository, imageStore: container.imageStore))
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(settingsRepository: container.settingsRepository, notificationScheduler: container.notificationScheduler, passcodeManager: container.passcodeManager))
        _passcodeViewModel = StateObject(wrappedValue: PasscodeViewModel(passcodeManager: container.passcodeManager, settingsRepository: container.settingsRepository))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: dashboardViewModel,
                          addItemViewModel: addItemViewModel,
                          onOpenSettings: { showingSettings = true },
                          onShowCloseout: { Task { await checkRollover() } })
                .tabItem { Label("Dashboard", systemImage: "house") }
                .tag(Tab.dashboard)

            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(Tab.add)

            HistoryView(viewModel: historyViewModel)
            .tabItem { Label("History", systemImage: "clock") }
            .tag(Tab.history)

        }
        .sheet(item: $closeoutSummary) { summary in
            MonthCloseoutView(viewModel: MonthCloseoutViewModel(summary: summary, haptics: container.hapticManager)) { item in
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
        .fullScreenCover(isPresented: $isLocked) {
            PasscodeLockView(viewModel: passcodeViewModel) {
                isLocked = false
            }
        }
        .onAppear {
            dashboardViewModel.refresh()
            historyViewModel.refresh()
            settingsViewModel.load()
            Task { await checkRollover() }
            Task { await refreshLockState() }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                Task {
                    await checkRollover()
                    await refreshLockState()
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .add {
                showingAddSheet = true
                selectedTab = lastNonAddTab
            } else {
                lastNonAddTab = newValue
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
