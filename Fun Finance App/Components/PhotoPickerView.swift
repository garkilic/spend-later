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
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Text("Select Photo")
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
                        }
                    } catch {
                        await MainActor.run {
                            onError?("Failed to load image")
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
