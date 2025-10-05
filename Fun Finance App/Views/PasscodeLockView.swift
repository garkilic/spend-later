import SwiftUI

struct PasscodeLockView: View {
    @StateObject private var viewModel: PasscodeViewModel
    let onUnlocked: () -> Void

    init(viewModel: PasscodeViewModel, onUnlocked: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onUnlocked = onUnlocked
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter Passcode")
                .font(.title)
                .bold()
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(Color.secondary, lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .fill(index < viewModel.digits.count ? Color.primary : Color.clear)
                                .frame(width: 12, height: 12)
                        )
                }
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
            numberPad
            Button("Clear") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .onChange(of: viewModel.isUnlocked) { _, newValue in
            if newValue {
                onUnlocked()
            }
        }
        .onAppear { viewModel.load() }
    }
}

private extension PasscodeLockView {
    var numberPad: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { row in
                HStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { column in
                        let number = row * 3 + column
                        NumberButton(label: "\(number)") {
                            viewModel.append(number)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                Spacer()
                NumberButton(label: "0") {
                    viewModel.append(0)
                }
                Button(action: { viewModel.backspace() }) {
                    Image(systemName: "delete.left")
                        .frame(width: 60, height: 60)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
        }
    }

    struct NumberButton: View {
        let label: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    return PasscodeLockView(viewModel: PasscodeViewModel(passcodeManager: container.passcodeManager, settingsRepository: container.settingsRepository)) {}
}
#endif
