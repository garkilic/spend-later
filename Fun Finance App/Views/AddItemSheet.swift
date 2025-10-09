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
                VStack(spacing: Spacing.lg) {
                    // Large prominent camera section
                    cameraSection

                    // Input fields card
                    inputFieldsCard

                    // Error message
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                }
                .padding(Spacing.sideGutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Record Impulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSave)
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

    private var canSave: Bool {
        !viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.isSaving
    }

    @ViewBuilder
    private var cameraSection: some View {
        Button {
            showingPhotoSource = true
        } label: {
            ZStack {
                if let image = viewModel.image {
                    // Show captured image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            // Edit indicator
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("Tap to change")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .padding(12)
                        }
                } else {
                    // Empty state - imperative to add photo
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentFallback.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.accentFallback)
                        }

                        VStack(spacing: 4) {
                            Text("Add Photo")
                                .font(.headline)
                                .foregroundStyle(Color.primaryFallback)

                            Text("Capture what you resisted")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryFallback)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.accentFallback.opacity(0.08),
                                Color.accentFallback.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .strokeBorder(
                        viewModel.image == nil
                            ? Color.accentFallback.opacity(0.3)
                            : Color.successFallback.opacity(0.5),
                        lineWidth: viewModel.image == nil ? 2 : 3,
                        antialiased: true
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var inputFieldsCard: some View {
        VStack(spacing: 0) {
            // Title
            inputRow(
                icon: "tag.fill",
                iconColor: Color.accentFallback,
                placeholder: "What did you resist?",
                field: TextField("What did you resist?", text: $viewModel.title)
                    .disableAutocorrection(true)
                    .font(.body.weight(.medium))
            )

            Divider()
                .padding(.leading, 60)

            // Price
            inputRow(
                icon: "dollarsign.circle.fill",
                iconColor: Color.successFallback,
                placeholder: "Price",
                field: TextField("Price", text: $viewModel.priceText)
                    .keyboardType(.decimalPad)
                    .disableAutocorrection(true)
                    .font(.body.weight(.medium))
            )

            Divider()
                .padding(.leading, 60)

            // URL
            inputRow(
                icon: "link.circle.fill",
                iconColor: Color.accentFallback,
                placeholder: "Product URL (Optional)",
                field: TextField("Product URL", text: $viewModel.urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.body)
            )

            Divider()
                .padding(.leading, 60)

            // Notes
            inputRow(
                icon: "note.text",
                iconColor: Color.orange,
                placeholder: "Notes (Optional)",
                alignment: .top,
                field: TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .disableAutocorrection(true)
                    .multilineTextAlignment(.leading)
                    .font(.body)
                    .padding(.vertical, 8)
            )

            Divider()
                .padding(.leading, 60)

            // Tags
            inputRow(
                icon: "number",
                iconColor: Color.purple,
                placeholder: "Tags (Optional)",
                field: TextField("Tags (comma separated)", text: $viewModel.tagsText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.body)
            )
        }
        .background(Color.surfaceElevatedFallback)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(Color.separatorFallback.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func inputRow<Field: View>(
        icon: String,
        iconColor: Color,
        placeholder: String,
        alignment: VerticalAlignment = .center,
        field: Field
    ) -> some View {
        HStack(alignment: alignment, spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            field
                .foregroundStyle(Color.primaryFallback)
        }
        .padding(Spacing.md)
        .background(Color.surfaceElevatedFallback)
    }

    @ViewBuilder
    private func errorBanner(_ error: String) -> some View {
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
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listRow))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.listRow)
                .strokeBorder(Color.warningFallback.opacity(0.3), lineWidth: 1)
        )
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
