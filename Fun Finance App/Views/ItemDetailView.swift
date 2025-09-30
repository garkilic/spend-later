import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ItemDetailViewModel
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

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
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save") { saveChanges() }
                        .disabled(viewModel.isSaving)
                } else {
                    Button("Edit") { isEditing = true }
                }
            }
        }
        .confirmationDialog("Delete \(viewModel.item.title)?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete(viewModel.item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .onAppear { viewModel.refreshFromStore() }
    }
}

private extension ItemDetailView {
    var imageSection: some View {
        Section {
            Group {
                if let image = imageProvider(viewModel.item) {
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
        }
    }

    var infoSection: some View {
        Section("Price") {
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

}
