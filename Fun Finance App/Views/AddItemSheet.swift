import SwiftUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddItemViewModel
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingSourceChooser = false
    @State private var cameraError: String?
    @FocusState private var focusedField: Field?
    @State private var isViewReady = false // Prevents initial render issues

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
                    .id("photo-section") // Stable identity

                detailsSection
                    .id("details-section") // Stable identity

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Record Impulse")
            .navigationBarTitleDisplayMode(.inline) // Faster rendering
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!viewModel.isValid)
                }
            }
            .transaction { transaction in
                // Disable animations for initial render to prevent lag
                transaction.animation = nil
            }
            .task {
                // Allow view hierarchy to fully load before enabling interactions
                try? await Task.sleep(for: .milliseconds(200))
                isViewReady = true
            }
            .interactiveDismissDisabled(!isViewReady) // Prevent gesture conflicts during load
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView(onImagePicked: { image in
                    viewModel.image = image
                }, onError: { error in
                    cameraError = error
                })
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(onImageCaptured: { image in
                    viewModel.image = image
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
            .sheet(isPresented: $showingSourceChooser) {
                PhotoSourcePickerView(
                    hasExistingPhoto: viewModel.image != nil,
                    onSelectCamera: { showingCamera = true },
                    onSelectLibrary: { showingPhotoPicker = true },
                    onRemovePhoto: viewModel.image != nil ? { viewModel.image = nil } : nil
                )
                .presentationDetents([.medium, .large])
            }
            .onChange(of: focusedField) { oldValue, newValue in
                // Trigger preview when leaving URL field
                if oldValue == .url && newValue != .url {
                    viewModel.requestLinkPreview()
                }
            }
        }
    }
}

private extension AddItemSheet {
    @ViewBuilder
    var photoSection: some View {
        Section("Photo") {
            PhotoSectionContent(
                previewImage: viewModel.previewImage,
                userImage: viewModel.image,
                onTapCamera: { showingCamera = true }
            )
            .frame(maxWidth: .infinity)
        }
    }

    var detailsSection: some View {
        DetailsSectionContent(
            viewModel: viewModel,
            focusedField: $focusedField,
            isViewReady: isViewReady,
            onPriceFieldExit: { viewModel.updatePriceFromText() },
            onURLSubmit: { viewModel.requestLinkPreview() }
        )
    }

    func save() async {
        // Dismiss keyboard before saving to prevent snapshot warning
        focusedField = nil

        let success = await viewModel.save()
        if success {
            dismiss()
        }
    }
}

// MARK: - Optimized Child Views

/// Isolated photo section - only re-renders when images change
private struct PhotoSectionContent: View, Equatable {
    let previewImage: UIImage?
    let userImage: UIImage?
    let onTapCamera: () -> Void

    static func == (lhs: PhotoSectionContent, rhs: PhotoSectionContent) -> Bool {
        lhs.previewImage === rhs.previewImage && lhs.userImage === rhs.userImage
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            if let preview = previewImage {
                PreviewImageView(image: preview)
                    .id(ObjectIdentifier(preview))
            } else {
                PhotoPreviewPlaceholder(userImage: userImage, onTap: onTapCamera)
                    .id(userImage != nil ? ObjectIdentifier(userImage!) : nil)

                Text("Optional: attach a quick photo of what you resisted.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Cached image view - prevents re-rendering from SwiftUI Image conversion
private struct PreviewImageView: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .drawingGroup() // Flattens layer hierarchy for performance
    }
}

/// Camera placeholder - isolated from text field updates
private struct PhotoPreviewPlaceholder: View {
    let userImage: UIImage?
    let onTap: () -> Void
    @State private var isImageReady = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundStyle(Color.accentColor.opacity(0.6))
                .frame(height: 220)
                .overlay(alignment: .center) {
                    VStack(spacing: 8) {
                        Image(systemName: userImage == nil ? "camera" : "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 40, weight: .medium))
                        Text(userImage == nil ? "Tap to add a photo" : "Change photo")
                            .font(.headline)
                    }
                    .foregroundStyle(Color.accentColor)
                }

            if let image = userImage, isImageReady {
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
                    .drawingGroup()
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityLabel(userImage == nil ? "Add a photo" : "Change photo")
        .accessibilityAddTraits(.isButton)
        .onChange(of: userImage) { _, newImage in
            if newImage != nil {
                // Delay image render to prevent blocking
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    withAnimation(.easeIn(duration: 0.2)) {
                        isImageReady = true
                    }
                }
            } else {
                isImageReady = false
            }
        }
        .onAppear {
            if userImage != nil {
                isImageReady = true
            }
        }
    }
}

/// Isolated details section - observes only relevant ViewModel properties
private struct DetailsSectionContent: View {
    @ObservedObject var viewModel: AddItemViewModel
    @FocusState.Binding var focusedField: AddItemSheet.Field?
    let isViewReady: Bool
    let onPriceFieldExit: () -> Void
    let onURLSubmit: () -> Void

    var body: some View {
        Section {
            // Title field with icon
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentFallback)
                    .frame(width: 28, height: 28)
                    .background(Color.accentFallback.opacity(0.12))
                    .clipShape(Circle())

                TextField("What did you resist?", text: $viewModel.title)
                    .focused($focusedField, equals: isViewReady ? .title : nil)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .font(.body)
                    .disabled(!isViewReady)
                    .onSubmit {
                        if isViewReady {
                            focusedField = .price
                        }
                    }
            }
            .padding(.vertical, 4)
            .id("title-field")

            // Price field with enhanced styling
            PriceInputRow(
                priceText: $viewModel.priceText,
                focusedField: $focusedField,
                isViewReady: isViewReady,
                onExit: onPriceFieldExit
            )
            .id("price-field")

            // URL field with icon
            URLInputRow(
                urlText: $viewModel.urlText,
                isFetchingPreview: viewModel.isFetchingPreview,
                focusedField: $focusedField,
                isViewReady: isViewReady,
                onSubmit: onURLSubmit
            )
            .id("url-field")

            // Notes field with icon
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentFallback)
                    .frame(width: 28, height: 28)
                    .background(Color.accentFallback.opacity(0.12))
                    .clipShape(Circle())
                    .padding(.top, 4)

                TextField("Add notes (optional)", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: isViewReady ? .notes : nil)
                    .font(.body)
                    .disabled(!isViewReady)
            }
            .padding(.vertical, 4)
            .id("notes-field")

            // Tags field with icon
            HStack(spacing: 12) {
                Image(systemName: "number")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentFallback)
                    .frame(width: 28, height: 28)
                    .background(Color.accentFallback.opacity(0.12))
                    .clipShape(Circle())

                TextField("Tags (comma separated)", text: $viewModel.tagsText)
                    .focused($focusedField, equals: isViewReady ? .tags : nil)
                    .font(.body)
                    .disabled(!isViewReady)
            }
            .padding(.vertical, 4)
            .id("tags-field")
        } header: {
            HStack {
                Text("DETAILS")
                    .sectionHeaderStyle()
                Spacer()
            }
        }
    }
}

/// Price input row - isolated to prevent form-wide re-renders
private struct PriceInputRow: View {
    @Binding var priceText: String
    @FocusState.Binding var focusedField: AddItemSheet.Field?
    let isViewReady: Bool
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.successFallback)
                .frame(width: 28, height: 28)
                .background(Color.successFallback.opacity(0.12))
                .clipShape(Circle())

            TextField("0.00", text: $priceText)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: isViewReady ? .price : nil)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primaryFallback)
                .accessibilityLabel("Price in US dollars")
                .disabled(!isViewReady)
                .onChange(of: focusedField) { _, newValue in
                    // Only trigger exit when field loses focus
                    if newValue != .price && isViewReady {
                        onExit()
                    }
                }
        }
        .padding(.vertical, 4)
        .toolbar {
            if isViewReady && focusedField == .price {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        onExit()
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// URL input row - isolated to prevent affecting other fields
private struct URLInputRow: View {
    @Binding var urlText: String
    let isFetchingPreview: Bool
    @FocusState.Binding var focusedField: AddItemSheet.Field?
    let isViewReady: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentFallback)
                    .frame(width: 28, height: 28)
                    .background(Color.accentFallback.opacity(0.12))
                    .clipShape(Circle())

                TextField("Product URL (optional)", text: $urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: isViewReady ? .url : nil)
                    .submitLabel(.done)
                    .font(.body)
                    .disabled(!isViewReady)
                    .onSubmit {
                        if isViewReady {
                            onSubmit()
                        }
                    }
            }
            .padding(.vertical, 4)

            if isFetchingPreview {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                    Text("Fetching preview…")
                        .font(.caption)
                        .foregroundStyle(Color.accentFallback)
                }
                .padding(.leading, 40)
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
