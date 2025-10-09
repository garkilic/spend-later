import SwiftUI
import PhotosUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ItemDetailViewModel
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingImageSourcePicker = false
    @State private var cameraError: String?
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title
        case notes
        case tags
    }

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
        formContent
            .navigationTitle(viewModel.item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Delete \(viewModel.item.title)?", isPresented: $showDeleteConfirmation, presenting: viewModel.item) { item in
                deleteAlert(item: item)
            } message: { item in
                deleteAlertMessage(item: item)
            }
            .alert("Error", isPresented: errorBinding) {
                errorAlertActions
            } message: {
                errorAlertMessage
            }
            .sheet(isPresented: $showingImageSourcePicker, content: photoSourceSheet)
            .onChange(of: photoPickerItem) { _, newItem in
                handlePhotoSelection(newItem)
            }
            .fullScreenCover(isPresented: $showingCamera, content: cameraView)
            .alert("Camera Error", isPresented: cameraErrorBinding) {
                cameraErrorActions
            } message: {
                cameraErrorMessage
            }
            .onChange(of: showingCamera) { _, isShowing in
                if isShowing { focusedField = nil }
            }
            .onChange(of: showingImageSourcePicker) { _, isShowing in
                if isShowing { focusedField = nil }
            }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            imageSection
            titleSection
            infoSection
            notesSection
            tagsSection
            linkSection

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Item", systemImage: "trash")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    // MARK: - Alert Builders

    @ViewBuilder
    private func deleteAlert(item: WantedItemDisplay) -> some View {
        Button("Delete", role: .destructive) {
            onDelete(item)
            dismiss()
        }
        Button("Cancel", role: .cancel) {}
    }

    @ViewBuilder
    private func deleteAlertMessage(item: WantedItemDisplay) -> some View {
        Text("Are you sure you want to delete this item?")
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })
    }

    @ViewBuilder
    private var errorAlertActions: some View {
        Button("OK", role: .cancel) {}
    }

    @ViewBuilder
    private var errorAlertMessage: some View {
        if let message = viewModel.errorMessage {
            Text(message)
        }
    }

    private var cameraErrorBinding: Binding<Bool> {
        Binding(get: { cameraError != nil }, set: { if !$0 { cameraError = nil } })
    }

    @ViewBuilder
    private var cameraErrorActions: some View {
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
    }

    @ViewBuilder
    private var cameraErrorMessage: some View {
        if let error = cameraError {
            Text(error)
        }
    }

    // MARK: - Sheet Builders

    @ViewBuilder
    private func photoSourceSheet() -> some View {
        PhotoSourcePickerView(
            hasExistingPhoto: viewModel.editedImage != nil || imageProvider(viewModel.item) != nil,
            photoPickerItem: $photoPickerItem,
            onSelectCamera: {
                showingCamera = true
            },
            onRemovePhoto: {
                viewModel.editedImage = nil
                viewModel.hasImageChanged = true
            }
        )
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func cameraView() -> some View {
        CameraView(onImageCaptured: { image in
            viewModel.editedImage = image
            viewModel.hasImageChanged = true
        }, onError: { error in
            cameraError = error
        })
        .ignoresSafeArea()
    }

    private func handlePhotoSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let newItem = newItem {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.editedImage = image
                            viewModel.hasImageChanged = true
                            photoPickerItem = nil
                        }
                    }
                } catch {
                    await MainActor.run {
                        cameraError = "Failed to load image"
                        photoPickerItem = nil
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        focusedField = nil // Dismiss keyboard
        viewModel.saveChanges()
        if viewModel.errorMessage == nil {
            isEditing = false
            onUpdate(viewModel.item)
        }
    }

    private func cancelEditing() {
        focusedField = nil // Dismiss keyboard
        viewModel.refreshFromStore()
        viewModel.editedImage = nil
        viewModel.hasImageChanged = false
        isEditing = false
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

    var infoSection: some View {
        Section("Price") {
            if isEditing {
                HStack {
                    Text("$")
                        .font(.title3)
                    TextField("0.00", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                        .font(.title3)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CurrencyFormatter.string(from: viewModel.item.price))
                        .font(.title3)
                        .foregroundStyle(.primary)
                    if viewModel.item.priceWithTax != viewModel.item.price {
                        Text("With tax: \(CurrencyFormatter.string(from: viewModel.item.priceWithTax))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    var titleSection: some View {
        Section("Title") {
            if isEditing {
                TextField("Title", text: $viewModel.title)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .title)
            } else {
                Text(viewModel.item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .padding(.vertical, 8)
            }
        }
    }

    var notesSection: some View {
        Section("Notes") {
            if isEditing {
                ZStack(alignment: .topLeading) {
                    if viewModel.notes.isEmpty {
                        Text("Add notes...")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $viewModel.notes)
                        .frame(height: 100)
                        .focused($focusedField, equals: .notes)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let notes = viewModel.item.notes, !notes.isEmpty {
                        Text(notes)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("No notes")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    var tagsSection: some View {
        Section("Tags") {
            if isEditing {
                TextField("Comma separated tags", text: $viewModel.tagsText)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .tags)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    if viewModel.item.tags.isEmpty {
                        Text("No tags")
                            .foregroundStyle(.secondary)
                    } else {
                        TagListView(tags: viewModel.item.tags)
                    }
                }
                .padding(.vertical, 8)
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
                    HStack(spacing: 12) {
                        Label(urlString, systemImage: "link")
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
            } else {
                Text("No link provided")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
}
