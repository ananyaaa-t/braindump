import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension Notification.Name {
    static let pageSoftDeleted = Notification.Name("pageSoftDeleted")
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var allPages: [Page]
    @AppStorage("hasManualPageOrder") private var hasManualOrder = false
    @State private var searchText = ""
    @State private var undoToastPage: Page?
    @State private var undoDismissTask: Task<Void, Never>?
    @State private var showingRecentlyDeleted = false
    @State private var draggingPage: Page?

    init() {}

    private var pages: [Page] {
        allPages.filter { !$0.isTrashed }
    }

    private var recentlyDeletedPages: [Page] {
        allPages.filter(\.isTrashed)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        searchField

                        if pages.isEmpty {
                            emptyState
                        } else if isSearching, filteredPages.isEmpty {
                            noResultsState
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(isSearching ? filteredPages : orderedPages) { page in
                                    NavigationLink(value: page) {
                                        NoteCard(page: page)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            softDelete(page)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .opacity(draggingPage?.persistentModelID == page.persistentModelID ? 0.5 : 1)
                                    .onDrag {
                                        draggingPage = page
                                        return NSItemProvider(object: page.uuid.uuidString as NSString)
                                    }
                                    .onDrop(
                                        of: [.text],
                                        delegate: PageGridDropDelegate(
                                            target: page,
                                            draggingPage: $draggingPage,
                                            orderedPages: orderedPages,
                                            onCommit: { hasManualOrder = true }
                                        )
                                    )
                                }
                            }

                            if !recentlyDeletedPages.isEmpty {
                                recentlyDeletedRow
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)

                fab
            }
            .background(Color.paper)
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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Braindump")
                    .font(AppFont.display(32))
                    .foregroundStyle(.ink)

                Text("\(pages.count) note\(pages.count == 1 ? "" : "s")")
                    .font(AppFont.body(13))
                    .foregroundStyle(.dune)
            }

            Spacer()

            avatarBadge
        }
    }

    private var avatarBadge: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFill()
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.dune)
            TextField("Search notes…", text: $searchText)
                .font(AppFont.body(14))
                .foregroundStyle(.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.hairline.opacity(0.5))
        )
    }

    private var fab: some View {
        Button(action: addPage) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.brandAccent)
                )
                .shadow(color: Color.brandAccent.opacity(0.45), radius: 16, y: 8)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        .accessibilityLabel("New page")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No pages yet")
                .font(AppFont.display(22))
                .foregroundStyle(.ink)
            Text("Tap + to start one")
                .font(AppFont.body(14))
                .foregroundStyle(.dune)
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
    }

    private var noResultsState: some View {
        VStack(spacing: 6) {
            Text("No matches")
                .font(AppFont.display(22))
                .foregroundStyle(.ink)
            Text("Try a different search")
                .font(AppFont.body(14))
                .foregroundStyle(.dune)
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
    }

    private var recentlyDeletedRow: some View {
        Button {
            showingRecentlyDeleted = true
        } label: {
            Text("Recently deleted (\(recentlyDeletedPages.count))")
                .font(AppFont.body(13))
                .foregroundStyle(.dune)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
        }
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
                    .font(AppFont.bodyBold(14))
                    .foregroundStyle(.ink)
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

        let lowered = query.lowercased()
        let literalMatches = orderedPages.filter { page in
            page.title.lowercased().contains(lowered)
                || page.paragraphs.contains { $0.text.lowercased().contains(lowered) }
        }
        let scored = orderedPages.compactMap { page -> (Page, Double)? in
            NoteAnalyzer.searchDistance(page: page, query: query).map { (page, $0) }
        }

        if scored.count == orderedPages.count {
            let literalIDs = Set(literalMatches.map(\.persistentModelID))
            let semanticMatches = scored.sorted { $0.1 < $1.1 }
                .filter { $0.1 < 1.1 && !literalIDs.contains($0.0.persistentModelID) }
                .map(\.0)
            return literalMatches + semanticMatches
        }

        return literalMatches
    }

    private func addPage() {
        let lowestSortOrder = pages.map(\.sortOrder).min() ?? 0
        let page = Page(sortOrder: lowestSortOrder - 1)
        modelContext.insert(page)
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

/// Drives drag-to-reorder for the home screen's note card grid: as the
/// dragged card hovers over another, moves it to that position in a local
/// snapshot of `orderedPages` and immediately writes back `sortOrder` on
/// the affected models, so `@Query`'s live result re-sorts to match while
/// the drag is still in progress (mirroring the reordering feel `List`'s
/// built-in `onMove` gave for free, which isn't available on `LazyVGrid`).
private struct PageGridDropDelegate: DropDelegate {
    let target: Page
    @Binding var draggingPage: Page?
    let orderedPages: [Page]
    let onCommit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingPage,
              draggingPage.persistentModelID != target.persistentModelID,
              let fromIndex = orderedPages.firstIndex(where: { $0.persistentModelID == draggingPage.persistentModelID }),
              let toIndex = orderedPages.firstIndex(where: { $0.persistentModelID == target.persistentModelID })
        else { return }

        var reordered = orderedPages
        reordered.move(
            fromOffsets: IndexSet(integer: fromIndex),
            toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
        )
        for (index, page) in reordered.enumerated() where page.sortOrder != index {
            page.sortOrder = index
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingPage = nil
        onCommit()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

/// A single note on the home screen's grid: a colored "sticky note" card
/// tinted per `page.color`, with an optional tag chip, title, preview
/// snippet, and relative timestamp -- all text tinted to the card's own
/// color (`page.color.textColor`) rather than the app-wide neutral ink.
private struct NoteCard: View {
    let page: Page
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let tag = page.tags.first {
                HStack {
                    Spacer(minLength: 0)
                    tagChip(tag)
                }
            }

            Text(page.title.isEmpty ? "Untitled" : page.title)
                .font(AppFont.display(15))
                .foregroundStyle(page.color.textColor)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(page.previewText)
                .font(AppFont.body(12))
                .foregroundStyle(page.color.textColor.opacity(0.75))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            Text(Self.timeAgo(page.updatedAt))
                .font(AppFont.body(10))
                .foregroundStyle(page.color.textColor.opacity(0.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(page.color.color)
        )
        .shadow(color: page.color.textColor.opacity(0.18), radius: 12, y: 4)
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .bold))
            Text(tag.capitalized)
                .font(AppFont.bodyBold(10))
        }
        .foregroundStyle(page.color.textColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(0.45)))
    }

    private static func timeAgo(_ date: Date) -> String {
        let minutes = max(0, Int(Date.now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Page.self, Paragraph.self], inMemory: true)
}
