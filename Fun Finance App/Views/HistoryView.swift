import SwiftUI
import UIKit

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    private let timeFormatter: DateFormatter

    init(viewModel: HistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        self.timeFormatter = formatter
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
                        Section(header: sectionHeader(title: section.title)) {
                            ForEach(section.items) { item in
                                HistoryItemRow(item: item,
                                               image: viewModel.image(for: item),
                                               timeString: timeFormatter.string(from: item.createdAt))
                                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                    .listRowBackground(Color.clear)
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

    func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.primary.opacity(0.75))
    }
}

private struct HistoryItemRow: View {
    let item: WantedItemDisplay
    let image: UIImage?
    let timeString: String

    var body: some View {
        HStack(spacing: 16) {
            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                Text(timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(CurrencyFormatter.string(from: item.price))
                .font(.headline)
                .foregroundStyle(Color(red: 0.0, green: 0.5, blue: 0.33))
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
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.0, green: 0.6, blue: 0.35).opacity(0.15))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(Color(red: 0.0, green: 0.6, blue: 0.35).opacity(0.8))
                )
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let vm = HistoryViewModel(monthRepository: container.monthRepository,
                              itemRepository: container.itemRepository,
                              imageStore: container.imageStore)
    return HistoryView(viewModel: vm)
}
#endif
