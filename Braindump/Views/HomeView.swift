import SwiftUI
import SwiftData

extension Notification.Name {
    static let pageSoftDeleted = Notification.Name("pageSoftDeleted")
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPages: [Page]
    @AppStorage("hasManualPageOrder") private var hasManualOrder = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var undoToastPage: Page?
    @State private var undoDismissTask: Task<Void, Never>?
    @State private var showingRecentlyDeleted = false
    @FocusState private var searchFieldFocused: Bool

    init() {}

    private var pages: [Page] {
        allPages.filter { !$0.isTrashed }
    }

    private var recentlyDeletedPages: [Page] {
        allPages.filter(\.isTrashed)
    }

    var body: some View {
        NavigationStack {
            Group {
                if pages.isEmpty {
                    emptyState
                } else if isSearching, filteredPages.isEmpty {
                    noResultsState
                } else {
                    List {
                        ForEach(isSearching ? filteredPages : orderedPages) { page in
                            NavigationLink(value: page) {
                                PageRow(page: page)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    softDelete(page)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: isSearching ? nil : movePages)

                        if !isSearching, !recentlyDeletedPages.isEmpty {
                            recentlyDeletedRow
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 20)
                }
            }
            .background(Color.paper)
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    header
                    if isSearching {
                        searchField
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let undoToastPage {
                    undoToast(for: undoToastPage)
                }
            }
            .navigationDestination(for: Page.self) { page in
                PageView(page: page)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(.ink)
        .sheet(isPresented: $showingRecentlyDeleted) {
            RecentlyDeletedView(pages: recentlyDeletedPages)
        }
        .onAppear(perform: purgeExpiredPages)
        .onReceive(NotificationCenter.default.publisher(for: .pageSoftDeleted)) { notification in
            guard let pageID = notification.userInfo?["pageID"] as? PersistentIdentifier,
                  let page = allPages.first(where: { $0.persistentModelID == pageID }) else { return }
            presentUndoToast(for: page)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("your pages")
                .font(AppFont.display(34))
                .foregroundStyle(.ink)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSearching.toggle()
                    if !isSearching { searchText = "" }
                }
                searchFieldFocused = isSearching
            } label: {
                Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(.dune)
            }
            .accessibilityLabel(isSearching ? "Close search" : "Search pages")

            Button(action: addPage) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.dune)
            }
            .accessibilityLabel("New page")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.paper)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.dune)
            TextField("search your pages", text: $searchText)
                .font(AppFont.body(16))
                .foregroundStyle(.ink)
                .focused($searchFieldFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.hairline.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .background(Color.paper)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("no pages yet")
                .font(AppFont.display(24))
                .foregroundStyle(.ink)
            Text("tap + to start one")
                .font(AppFont.body(15))
                .foregroundStyle(.dune)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var noResultsState: some View {
        VStack(spacing: 6) {
            Text("no matches")
                .font(AppFont.display(24))
                .foregroundStyle(.ink)
            Text("try a different search")
                .font(AppFont.body(15))
                .foregroundStyle(.dune)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var recentlyDeletedRow: some View {
        Button {
            showingRecentlyDeleted = true
        } label: {
            Text("recently deleted (\(recentlyDeletedPages.count))")
                .font(AppFont.body(13))
                .foregroundStyle(.dune)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func undoToast(for page: Page) -> some View {
        HStack {
            Text("\"\(page.title.isEmpty ? "untitled" : page.title)\" deleted")
                .font(AppFont.body(14))
                .foregroundStyle(.ink)
                .lineLimit(1)

            Spacer()

            Button {
                undoDismissTask?.cancel()
                page.restore()
                undoToastPage = nil
            } label: {
                Text("Undo")
                    .font(AppFont.body(14))
                    .foregroundStyle(.ink)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.hairline.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(Color.paper)
    }

    private var orderedPages: [Page] {
        if hasManualOrder {
            return pages.sorted { $0.sortOrder < $1.sortOrder }
        }
        return pages.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var filteredPages: [Page] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return orderedPages }

        let scored = orderedPages.compactMap { page -> (Page, Double)? in
            NoteAnalyzer.searchDistance(page: page, query: query).map { (page, $0) }
        }

        if scored.count == orderedPages.count {
            return scored.sorted { $0.1 < $1.1 }.filter { $0.1 < 1.1 }.map(\.0)
        }

        let lowered = query.lowercased()
        return orderedPages.filter { page in
            page.title.lowercased().contains(lowered)
                || page.paragraphs.contains { $0.text.lowercased().contains(lowered) }
        }
    }

    private func addPage() {
        let lowestSortOrder = pages.map(\.sortOrder).min() ?? 0
        let page = Page(sortOrder: lowestSortOrder - 1)
        modelContext.insert(page)
    }

    private func movePages(from source: IndexSet, to destination: Int) {
        var reordered = orderedPages
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, page) in reordered.enumerated() {
            page.sortOrder = index
        }
        hasManualOrder = true
    }

    private func softDelete(_ page: Page) {
        page.softDelete()
        presentUndoToast(for: page)
    }

    private func presentUndoToast(for page: Page) {
        undoDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            undoToastPage = page
        }
        undoDismissTask = Task {
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                undoToastPage = nil
            }
        }
    }

    private func purgeExpiredPages() {
        for page in allPages where page.isTrashed && (page.daysUntilPermanentDelete ?? 1) <= 0 {
            modelContext.delete(page)
        }
    }
}

private struct PageRow: View {
    let page: Page

    var body: some View {
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

                    Text(page.previewText)
                        .font(AppFont.body(15))
                        .foregroundStyle(.dune)
                        .lineLimit(1)
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
    HomeView()
        .modelContainer(for: [Page.self, Paragraph.self], inMemory: true)
}
