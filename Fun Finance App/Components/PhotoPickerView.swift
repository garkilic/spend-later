import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
    let onImagePicked: (UIImage) -> Void
    let onError: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?

    init(onImagePicked: @escaping (UIImage) -> Void, onError: ((String) -> Void)? = nil) {
        self.onImagePicked = onImagePicked
        self.onError = onError
    }

    var body: some View {
        NavigationStack {
            VStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)

                        Text("Select a Photo")
                            .font(.headline)

                        Text("Choose from your photo library")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Photo Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                onImagePicked(image)
                                dismiss()
                            }
                        } else {
                            await MainActor.run {
                                onError?("Failed to load image")
                                dismiss()
                            }
                        }
                    } catch {
                        await MainActor.run {
                            onError?("Failed to load image: \(error.localizedDescription)")
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(selectedItem != nil)
    }
}
