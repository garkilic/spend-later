import SwiftUI
import PhotosUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AddItemViewModel

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingPhotoSource = false
    @State private var cameraError: String?
    @FocusState private var isURLFieldFocused: Bool
    @State private var lastFetchedURL: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
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

                // Full-screen loading overlay
                if viewModel.isFetchingPreview {
                    FullScreenFetchingOverlay()
                }
            }
            .navigationTitle("Record Impulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.clear()
                        dismiss()
                    }
                    .disabled(viewModel.isFetchingPreview)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSave || viewModel.isFetchingPreview)
                }
            }
            .sheet(isPresented: $showingPhotoSource) {
                PhotoSourceSheet(
                    hasPhoto: viewModel.image != nil || viewModel.previewImage != nil,
                    photoPickerItem: $photoPickerItem,
                    onSelectCamera: { showingCamera = true },
                    onRemovePhoto: {
                        viewModel.image = nil
                        viewModel.previewImage = nil
                    }
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
            .onChange(of: isURLFieldFocused) { _, isFocused in
                if !isFocused {
                    fetchPreviewIfNeeded()
                }
            }
        }
    }

    private func fetchPreviewIfNeeded() {
        let trimmed = viewModel.urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Only fetch if URL changed and is not empty
        guard !trimmed.isEmpty, trimmed != lastFetchedURL else { return }

        lastFetchedURL = trimmed
        Task {
            await viewModel.requestLinkPreview()
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
                    // Show manually captured image
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
                } else if let previewImage = viewModel.previewImage {
                    // Show fetched preview image from URL
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            // Preview indicator
                            HStack(spacing: 6) {
                                Image(systemName: "link.circle.fill")
                                    .font(.system(size: 16))
                                Text("From URL • Tap to change")
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
                        viewModel.image != nil
                            ? Color.successFallback.opacity(0.5)  // Manual photo - green
                            : viewModel.previewImage != nil
                            ? Color.accentFallback.opacity(0.5)   // Preview image - accent
                            : Color.accentFallback.opacity(0.3),  // No image - faint accent
                        lineWidth: (viewModel.image != nil || viewModel.previewImage != nil) ? 3 : 2,
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

            // URL with inline loading indicator
            HStack(alignment: .center, spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentFallback.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentFallback)
                }

                TextField("Product URL", text: $viewModel.urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.body)
                    .foregroundStyle(Color.primaryFallback)
                    .focused($isURLFieldFocused)
                    .onSubmit {
                        fetchPreviewIfNeeded()
                    }

                // Inline loading indicator
                if viewModel.isFetchingPreview {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(Spacing.md)
            .background(Color.surfaceElevatedFallback)

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

private struct FullScreenFetchingOverlay: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var dotsOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // Full-screen blur background to block interaction
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .blur(radius: 0)

            // Blurred material background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Content card with animation
            VStack(spacing: 24) {
                // Animated circles
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentFallback.opacity(0.5), Color.accentFallback.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(rotationAngle))

                    // Inner rotating ring (opposite direction)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.successFallback.opacity(0.4), Color.successFallback.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-rotationAngle * 1.5))

                    // Center pulsing icon
                    ZStack {
                        Circle()
                            .fill(Color.accentFallback.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .scaleEffect(pulseScale)

                        Image(systemName: "link")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.accentFallback)
                    }
                }

                // Animated text with dots
                HStack(spacing: 4) {
                    Text("Fetching preview")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primaryFallback)

                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.accentFallback)
                                .frame(width: 4, height: 4)
                                .opacity(dotsOpacity)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                    value: dotsOpacity
                                )
                        }
                    }
                }

                // Helpful message
                Text("Please wait while we fetch\nproduct details...")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryFallback)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(48)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.surfaceElevatedFallback)
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onAppear {
            // Start rotation animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }

            // Start pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
            }

            // Start dots animation
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                dotsOpacity = 1.0
            }
        }
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
