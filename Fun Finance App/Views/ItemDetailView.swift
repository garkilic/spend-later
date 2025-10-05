import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ItemDetailViewModel
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingImageSourcePicker = false
    @State private var cameraError: String?

    let imageProvider: (WantedItemDisplay) -> UIImage?
    let onDelete: (WantedItemDisplay) -> Void
    let onUpdate: (WantedItemDisplay) -> Void

    init(viewModel: ItemDetailViewModel,
         imageProvider: @escaping (WantedItemDisplay) -> UIImage?,
         onDelete: @escaping (WantedItemDisplay) -> Void,
         onUpdate: @escaping (WantedItemDisplay) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.imageProvider = imageProvider
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    var body: some View {
        Form {
            imageSection
            titleSection
            infoSection
            notesSection
            tagsSection
            linkSection

            // Redemption confirmation section for winner items
            if viewModel.item.status == .redeemed && !viewModel.item.hasPurchaseConfirmation {
                redemptionSection
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Item", systemImage: "trash")
                }
            }
        }
        .navigationTitle(viewModel.item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if isEditing {
                    Button("Cancel") { cancelEditing() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save") { saveChanges() }
                        .disabled(viewModel.isSaving)
                } else {
                    Button("Edit") { isEditing = true }
                }
            }
        }
        .alert("Delete \(viewModel.item.title)?", isPresented: $showDeleteConfirmation, presenting: viewModel.item) { item in
            Button("Delete", role: .destructive) {
                onDelete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("Are you sure you want to delete this item?")
        }
        .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .sheet(isPresented: $showingImageSourcePicker) {
            PhotoSourcePickerView(
                hasExistingPhoto: viewModel.editedImage != nil || imageProvider(viewModel.item) != nil,
                onSelectCamera: {
                    showingCamera = true
                },
                onSelectLibrary: {
                    showingImagePicker = true
                },
                onRemovePhoto: {
                    viewModel.editedImage = nil
                    viewModel.hasImageChanged = true
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotoPickerView(onImagePicked: { image in
                viewModel.editedImage = image
                viewModel.hasImageChanged = true
            }, onError: { error in
                cameraError = error
            })
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(onImageCaptured: { image in
                viewModel.editedImage = image
                viewModel.hasImageChanged = true
            }, onError: { error in
                cameraError = error
            })
            .ignoresSafeArea()
        }
        .alert("Camera Error", isPresented: Binding(
            get: { cameraError != nil },
            set: { if !$0 { cameraError = nil } }
        )) {
            Button("OK", role: .cancel) {
                cameraError = nil
            }
            if cameraError?.contains("Settings") == true {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                    cameraError = nil
                }
            }
        } message: {
            if let error = cameraError {
                Text(error)
            }
        }
        .onAppear { viewModel.refreshFromStore() }
    }
}

private extension ItemDetailView {
    var imageSection: some View {
        Section {
            VStack(spacing: Spacing.sm) {
                Group {
                    // Show edited image if available, otherwise show original
                    if let editedImage = viewModel.editedImage {
                        Image(uiImage: editedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if viewModel.hasImageChanged {
                        // User removed the image
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            )
                    } else if let image = imageProvider(viewModel.item) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                if isEditing {
                    Button {
                        showingImageSourcePicker = true
                    } label: {
                        Label("Change Image", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    var redemptionSection: some View {
        Section {
            VStack(spacing: Spacing.md) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)

                    Text("Did you claim this reward?")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Let us know if you actually bought this item to adjust your savings total.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Spacing.md) {
                    Button {
                        viewModel.confirmPurchase(purchased: true)
                        onUpdate(viewModel.item)
                    } label: {
                        Label("Yes, I bought it", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        viewModel.confirmPurchase(purchased: false)
                        onUpdate(viewModel.item)
                    } label: {
                        Label("No, I didn't", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, Spacing.sm)
        } header: {
            Text("Redemption Confirmation")
        }
    }

    var infoSection: some View {
        Section("Price") {
            if isEditing {
                HStack {
                    Text("$")
                    TextField("0.00", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CurrencyFormatter.string(from: viewModel.item.price))
                        .font(.title3)
                    if viewModel.item.priceWithTax != viewModel.item.price {
                        Text("With tax: \(CurrencyFormatter.string(from: viewModel.item.priceWithTax))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var titleSection: some View {
        Section("Title") {
            if isEditing {
                TextField("Title", text: $viewModel.title)
                    .textInputAutocapitalization(.words)
            } else {
                Text(viewModel.item.title)
                    .font(.headline)
            }
        }
    }

    var notesSection: some View {
        Section("Notes") {
            if isEditing {
                TextEditor(text: $viewModel.notes)
                    .frame(minHeight: 80)
            } else if let notes = viewModel.item.notes, !notes.isEmpty {
                Text(notes)
            } else {
                Text("No notes")
                    .foregroundStyle(.secondary)
            }
        }
    }

    var tagsSection: some View {
        Section("Tags") {
            if isEditing {
                TextField("Comma separated tags", text: $viewModel.tagsText)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled()
            } else if viewModel.item.tags.isEmpty {
                Text("No tags")
                    .foregroundStyle(.secondary)
            } else {
                TagListView(tags: viewModel.item.tags)
            }
        }
    }

    var linkSection: some View {
        Section("Product URL") {
            if isEditing {
                TextField("https://example.com", text: $viewModel.productURLText)
                    .textInputAutocapitalization(.none)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            } else if let urlString = viewModel.item.productURL,
                      let url = URL(string: urlString) {
                Link(destination: url) {
                    Label(urlString, systemImage: "link")
                }
            } else {
                Text("No link provided")
                    .foregroundStyle(.secondary)
            }
        }
    }

    func saveChanges() {
        viewModel.saveChanges()
        if viewModel.errorMessage == nil {
            onUpdate(viewModel.item)
            isEditing = false
        }
    }

    func cancelEditing() {
        viewModel.refreshFromStore()
        viewModel.editedImage = nil
        viewModel.hasImageChanged = false
        isEditing = false
    }

}
