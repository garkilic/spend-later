import SwiftUI
import PhotosUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AddItemViewModel

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingPhotoSource = false
    @State private var cameraError: String?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.md) {
                        // Input fields card with integrated camera
                    VStack(spacing: 0) {
                        // Photo button
                        Button {
                            showingPhotoSource = true
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: viewModel.image == nil ? "camera.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(viewModel.image == nil ? Color.accentFallback : Color.successFallback)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        (viewModel.image == nil ? Color.accentFallback : Color.successFallback)
                                            .opacity(0.18)
                                    )
                                    .clipShape(Circle())

                                Text(viewModel.image == nil ? "Add Photo (Optional)" : "Photo Added")
                                    .foregroundStyle(Color.primaryFallback)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.secondaryFallback)
                            }
                            .padding(Spacing.md)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 48)

                        // Title
                        inputRow(
                            icon: "tag.fill",
                            color: Color.accentFallback,
                            field: TextField("What did you resist?", text: $viewModel.title)
                                .disableAutocorrection(true)
                        )

                        Divider().padding(.leading, 48)

                        // Price
                        inputRow(
                            icon: "dollarsign.circle.fill",
                            color: Color.successFallback,
                            field: TextField("Price", text: $viewModel.priceText)
                                .keyboardType(.decimalPad)
                                .disableAutocorrection(true)
                        )

                        Divider().padding(.leading, 48)

                        // URL
                        inputRow(
                            icon: "link.circle.fill",
                            color: Color.accentFallback,
                            field: TextField("Product URL", text: $viewModel.urlText)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        )

                        Divider().padding(.leading, 48)

                        // Notes
                        inputRow(
                            icon: "note.text",
                            color: Color.secondaryFallback,
                            alignment: .firstTextBaseline,
                            field: TextField("Notes", text: $viewModel.notes, axis: .vertical)
                                .lineLimit(3...6)
                                .disableAutocorrection(true)
                                .multilineTextAlignment(.leading)
                                .padding(.vertical, 4)
                        )

                        Divider().padding(.leading, 48)

                        // Tags
                        inputRow(
                            icon: "number",
                            color: Color.secondaryFallback,
                            field: TextField("Tags (comma separated)", text: $viewModel.tagsText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        )
                    }
                    .background(Color.surfaceElevatedFallback)
                    .cornerRadius(CornerRadius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.card)
                            .stroke(Color.separatorFallback.opacity(0.3), lineWidth: 1)
                    )

                    // Error message
                    if let error = viewModel.errorMessage {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.warningFallback)
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Color.primaryFallback)
                            Spacer()
                        }
                        .padding(Spacing.md)
                        .background(Color.warningFallback.opacity(0.1))
                        .cornerRadius(CornerRadius.listRow)
                    }
                    }
                    .padding(Spacing.sideGutter)
                }
                .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Record Impulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.accentFallback, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSaving)
                }
            }
            .sheet(isPresented: $showingPhotoSource) {
                PhotoSourceSheet(
                    hasPhoto: viewModel.image != nil,
                    photoPickerItem: $photoPickerItem,
                    onSelectCamera: { showingCamera = true },
                    onRemovePhoto: { viewModel.image = nil }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(
                    onImageCaptured: { viewModel.image = $0 },
                    onError: { cameraError = $0 }
                )
                .ignoresSafeArea()
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task {
                    if let newItem,
                       let data = try? await newItem.loadTransferable(type: Data.self),
                       let loadedImage = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.image = loadedImage
                            photoPickerItem = nil
                        }
                    }
                }
            }
            .alert("Camera Error", isPresented: .constant(cameraError != nil)) {
                Button("OK") { cameraError = nil }
            } message: {
                if let error = cameraError {
                    Text(error)
                }
            }
            .onChange(of: viewModel.title) { _, _ in
                if viewModel.errorMessage != nil { viewModel.errorMessage = nil }
            }
            .onChange(of: viewModel.priceText) { _, _ in
                if viewModel.errorMessage != nil { viewModel.errorMessage = nil }
            }
        }
    }

    @ViewBuilder
    private func inputRow<Field: View>(icon: String, color: Color, alignment: VerticalAlignment = .center, field: Field) -> some View {
        HStack(alignment: alignment, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.18))
                .clipShape(Circle())
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    // For multiline fields, align icon to top instead of center
                    dimensions[.top] + 16 // Half of icon height (32/2) for optical alignment
                }

            field
        }
        .padding(Spacing.md)
    }
}

private struct PhotoSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let hasPhoto: Bool
    @Binding var photoPickerItem: PhotosPickerItem?
    let onSelectCamera: () -> Void
    let onRemovePhoto: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    dismiss()
                    onSelectCamera()
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo")
                }
                .onChange(of: photoPickerItem) { _, _ in
                    if photoPickerItem != nil {
                        dismiss()
                    }
                }

                if hasPhoto {
                    Button(role: .destructive) {
                        onRemovePhoto()
                        dismiss()
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    return AddItemSheet(viewModel: AddItemViewModel(itemRepository: container.itemRepository))
}
#endif
