import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var showingPasscodeSheet = false
    @State private var newPasscode: String = ""
    @State private var confirmPasscode: String = ""

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminders") {
                    Toggle("Weekly temptation reminder", isOn: Binding(get: { viewModel.weeklyReminderEnabled }, set: { viewModel.toggleWeeklyReminder($0) }))
                    Toggle("Monthly draw reminder", isOn: Binding(get: { viewModel.monthlyReminderEnabled }, set: { viewModel.toggleMonthlyReminder($0) }))
                }

                Section("Passcode") {
                    Toggle("Require passcode", isOn: Binding(get: { viewModel.passcodeEnabled }, set: { handlePasscodeToggle($0) }))
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { viewModel.load() }
            .sheet(isPresented: $showingPasscodeSheet) {
                NavigationStack {
                    VStack(spacing: 16) {
                        SecureField("New passcode", text: $newPasscode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        SecureField("Confirm passcode", text: $confirmPasscode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        Button("Save", action: savePasscode)
                            .buttonStyle(.borderedProminent)
                            .disabled(!canSavePasscode)
                    }
                    .padding()
                    .navigationTitle("Set Passcode")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                resetPasscodeSheet()
                                showingPasscodeSheet = false
                                viewModel.passcodeEnabled = false
                            }
                        }
                    }
                }
            }
        }
    }
}

private extension SettingsView {
    func handlePasscodeToggle(_ enabled: Bool) {
        if enabled {
            showingPasscodeSheet = true
        } else {
            viewModel.disablePasscode()
        }
    }

    var canSavePasscode: Bool {
        newPasscode.count == 4 && newPasscode == confirmPasscode
    }

    func savePasscode() {
        viewModel.enablePasscode(with: newPasscode)
        resetPasscodeSheet()
        showingPasscodeSheet = false
    }

    func resetPasscodeSheet() {
        newPasscode = ""
        confirmPasscode = ""
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    return SettingsView(viewModel: SettingsViewModel(settingsRepository: container.settingsRepository, notificationScheduler: container.notificationScheduler, passcodeManager: container.passcodeManager))
}
#endif
