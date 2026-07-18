import SwiftUI
import SwiftData

struct RecentlyDeletedView: View {
    let pages: [Page]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var sortedPages: [Page] {
        pages.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedPages.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(sortedPages) { page in
                            row(for: page)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(page)
                                    } label: {
                                        Label("Delete Now", systemImage: "trash")
                                    }
                                    Button {
                                        page.restore()
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.dune)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 20)
                }
            }
            .background(Color.paper)
            .navigationTitle("recently deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(AppFont.body(16))
                            .foregroundStyle(.ink)
                    }
                }
            }
        }
        .tint(.ink)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("nothing here")
                .font(AppFont.display(22))
                .foregroundStyle(.ink)
            Text("deleted pages show up here for 30 days")
                .font(AppFont.body(14))
                .foregroundStyle(.dune)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func row(for page: Page) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(page.color.color)
                    .frame(width: 12, height: 12)
                    .padding(.top, 6)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title.isEmpty ? "untitled" : page.title)
                        .font(AppFont.display(20))
                        .foregroundStyle(.ink)

                    if let days = page.daysUntilPermanentDelete {
                        Text(days <= 1 ? "deletes today" : "deletes in \(days) days")
                            .font(AppFont.body(13))
                            .foregroundStyle(.dune)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 14)

            Rectangle()
                .fill(Color.hairline)
                .frame(height: 0.5)
        }
    }
}

#Preview {
    RecentlyDeletedView(pages: [])
        .modelContainer(for: [Page.self, Paragraph.self], inMemory: true)
}
