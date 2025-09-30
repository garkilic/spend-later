import SwiftUI
import UIKit

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    @State private var selectedItem: WantedItemDisplay?
    private let timeFormatter: DateFormatter
    private let makeDetailViewModel: (WantedItemDisplay) -> ItemDetailViewModel
    private let onItemDeleted: (WantedItemDisplay) -> Void

    init(viewModel: HistoryViewModel,
         makeDetailViewModel: @escaping (WantedItemDisplay) -> ItemDetailViewModel,
         onItemDeleted: @escaping (WantedItemDisplay) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        self.timeFormatter = formatter
        self.makeDetailViewModel = makeDetailViewModel
        self.onItemDeleted = onItemDeleted
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(.systemGroupedBackground), Color(red: 0.93, green: 0.98, blue: 0.95)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("History")
        }
        .onAppear { viewModel.refresh() }
        .sheet(item: $selectedItem) { item in
            detailSheet(for: item)
        }
    }
}

private extension HistoryView {
    var content: some View {
        Group {
            if viewModel.sections.isEmpty {
                ScrollView {
                    VStack(spacing: 24) {
                        EmptyStateView(title: "No entries yet",
                                       message: "Every time you skip a purchase it will show up here, grouped by the day you logged it.")
                            .padding(.top, 80)
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: sectionHeader(for: section)) {
                            ForEach(section.items) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    HistoryItemRow(item: item,
                                                   image: viewModel.image(for: item),
                                                   timeString: timeFormatter.string(from: item.createdAt))
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.delete(item)
                                        onItemDeleted(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .textCase(nil)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    func sectionHeader(for section: HistoryViewModel.HistorySection) -> some View {
        HStack {
            Text(section.title)
                .font(.headline)
            Spacer()
            Text(CurrencyFormatter.string(from: section.subtotal))
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
    }
}

private extension HistoryView {
    func detailSheet(for item: WantedItemDisplay) -> some View {
        let detailViewModel = makeDetailViewModel(item)
        return ItemDetailView(viewModel: detailViewModel,
                              imageProvider: { viewModel.image(for: $0) }) { deleted in
            viewModel.delete(deleted)
            onItemDeleted(deleted)
            selectedItem = nil
        } onUpdate: { _ in
            viewModel.refresh()
        }
    }
}

private struct HistoryItemRow: View {
    let item: WantedItemDisplay
    let image: UIImage?
    let timeString: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            thumbnail

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Text(CurrencyFormatter.string(from: item.priceWithTax))
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.0, green: 0.5, blue: 0.33))
                }
                if item.priceWithTax != item.price {
                    Text("Base: \(CurrencyFormatter.string(from: item.price))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !item.tags.isEmpty {
                    TagListView(tags: item.tags)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image, !item.imagePath.isEmpty {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 68, height: 68)
                .overlay(
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                )
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let vm = HistoryViewModel(monthRepository: container.monthRepository,
                              itemRepository: container.itemRepository,
                              imageStore: container.imageStore,
                              settingsRepository: container.settingsRepository)
    return HistoryView(viewModel: vm,
                       makeDetailViewModel: { item in
                           ItemDetailViewModel(item: item,
                                               itemRepository: container.itemRepository,
                                               settingsRepository: container.settingsRepository)
                       },
                       onItemDeleted: { _ in })
}
#endif
