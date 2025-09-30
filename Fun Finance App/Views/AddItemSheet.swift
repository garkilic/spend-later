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
                photoSection
                linkSection
                detailsSection
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Item")
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
            .confirmationDialog("Add a photo", isPresented: $showingSourceChooser, titleVisibility: .visible) {
                Button("Take Photo", systemImage: "camera") {
                    launch(with: .camera)
                }
                Button("Choose from Library", systemImage: "photo.on.rectangle") {
                    launch(with: .library)
                }
                if viewModel.image != nil {
                    Button("Remove Photo", role: .destructive) {
                        viewModel.image = nil
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: focusedField) { oldValue, newValue in
                if oldValue == .url, newValue != .url {
                    viewModel.requestLinkPreview()
                }
            }
        }
    }
}

private extension AddItemSheet {
    var linkSection: some View {
        Section("Product URL") {
            if let preview = viewModel.previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .clipped()
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            TextField("https://example.com/product", text: $viewModel.urlText)
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
                    Text("Fetching preview…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var photoSection: some View {
        Section("Photo") {
        VStack(alignment: .center, spacing: 12) {
            photoPreview
            Text("Optional: attach a quick photo of the temptation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
            TextField("Price (USD)", value: $viewModel.price, format: .currency(code: "USD"))
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .price)
                .accessibilityLabel("Price in US dollars")
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
