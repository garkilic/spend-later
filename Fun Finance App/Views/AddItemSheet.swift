import SwiftUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddItemViewModel
    @State private var showingPhotoPicker = false
    @State private var photoSource: PhotoSource = .library
    @State private var showingSourceChooser = false
    @FocusState private var focusedField: Field?

    enum Field {
        case url
        case title
        case price
        case notes
        case tags
    }

    init(viewModel: AddItemViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Photo section always at top
                photoSection

                detailsSection

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Log a Purchase")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView(source: photoSource) { image in
                    viewModel.image = image
                }
            }
            .sheet(isPresented: $showingSourceChooser) {
                PhotoSourcePickerView(
                    hasExistingPhoto: viewModel.image != nil,
                    onSelectCamera: { launch(with: .camera) },
                    onSelectLibrary: { launch(with: .library) },
                    onRemovePhoto: viewModel.image != nil ? { viewModel.image = nil } : nil
                )
                .presentationDetents([.medium, .large])
            }
            .onChange(of: focusedField) { newValue in
                if newValue != .url {
                    viewModel.requestLinkPreview()
                }
            }
        }
    }
}

private extension AddItemSheet {
    var photoSection: some View {
        Section("Photo") {
            VStack(alignment: .center, spacing: 12) {
                // Show preview image from URL if available, otherwise show photo picker
                if let preview = viewModel.previewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .clipped()
                } else {
                    photoPreview
                    Text("Optional: attach a quick photo of what you resisted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    var photoPreview: some View {
        Button {
            showingSourceChooser = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(Color.accentColor.opacity(0.6))
                    .frame(height: 220)
                    .overlay(alignment: .center) {
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.image == nil ? "camera" : "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 40, weight: .medium))
                            Text(viewModel.image == nil ? "Tap to add a photo" : "Change photo")
                                .font(.headline)
                        }
                        .foregroundStyle(Color.accentColor)
                    }

                if let image = viewModel.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .bottomTrailing) {
                            Label("Edit", systemImage: "slider.horizontal.3")
                                .padding(10)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                                .offset(x: -12, y: -12)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.image == nil ? "Add a photo" : "Change photo")
    }

    var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $viewModel.title)
                .focused($focusedField, equals: .title)
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .price
                }

            HStack {
                Text("$")
                    .foregroundColor(.secondary)
                TextField("0.00", text: $viewModel.priceText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .price)
                    .accessibilityLabel("Price in US dollars")
                    .onChange(of: focusedField) { newValue in
                        // Only update price when user leaves the field
                        if newValue != .price {
                            viewModel.updatePriceFromText()
                        }
                    }
            }

            // Product URL field
            VStack(alignment: .leading, spacing: 4) {
                TextField("Product URL (optional)", text: $viewModel.urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .url)
                    .submitLabel(.done)
                    .onSubmit { viewModel.requestLinkPreview() }

                if viewModel.isFetchingPreview {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Fetching preview…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3)
                .focused($focusedField, equals: .notes)
            TextField("Tags (comma separated)", text: $viewModel.tagsText)
                .focused($focusedField, equals: .tags)
        }
    }

    func launch(with source: PhotoSource) {
        photoSource = source
        showingPhotoPicker = true
    }

    func save() async {
        let success = await viewModel.save()
        if success {
            dismiss()
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    return AddItemSheet(viewModel: AddItemViewModel(itemRepository: container.itemRepository))
}
#endif
