import SwiftUI

struct PhotoSourcePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let hasExistingPhoto: Bool
    let onSelectCamera: () -> Void
    let onSelectLibrary: () -> Void
    let onRemovePhoto: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelectCamera()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 28)

                            Text("Take Photo")
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                    }

                    Button {
                        onSelectLibrary()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 28)

                            Text("Choose from Library")
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                    }
                }

                if hasExistingPhoto, let removeAction = onRemovePhoto {
                    Section {
                        Button(role: .destructive) {
                            removeAction()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.title3)
                                    .frame(width: 28)

                                Text("Remove Photo")

                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    PhotoSourcePickerView(
        hasExistingPhoto: true,
        onSelectCamera: {},
        onSelectLibrary: {},
        onRemovePhoto: {}
    )
}
#endif
