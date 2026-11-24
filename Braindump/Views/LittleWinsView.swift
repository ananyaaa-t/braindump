import SwiftUI
import SwiftData
import UIKit
import WidgetKit

struct LittleWinsView: View {
    private enum Tab: Hashable { case moments, goals, recaps, notes }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var pages: [Page]
    @State private var selectedTab = Tab.moments
    @State private var captureKind: GrowthKind?
    @State private var filter: GrowthKind?
    @State private var deletedPage: Page?
    @State private var errorMessage: String?
    @State private var showingRecentlyDeleted = false

    private var moments: [Page] {
        pages.filter { !$0.isTrashed && $0.isMoment && (filter == nil || $0.growthKind == filter) }
            .sorted { $0.eventDate > $1.eventDate }
    }

    private var goals: [Page] {
        pages.filter { !$0.isTrashed && $0.growthKind == .goal }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                momentsHome
                    .navigationDestination(for: Page.self) { PageView(page: $0) }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Moments", systemImage: "sparkles") }
            .tag(Tab.moments)

            NavigationStack {
                goalsHome
                    .navigationDestination(for: Page.self) { GoalDetailView(goal: $0) }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Goals", systemImage: "leaf") }
            .tag(Tab.goals)

            RecapsView()
                .tabItem { Label("Recaps", systemImage: "rectangle.stack") }
                .tag(Tab.recaps)

            HomeView()
                .tabItem { Label("Notes", systemImage: "note.text") }
                .tag(Tab.notes)
        }
        .tint(.ink)
        .sheet(item: $captureKind) { kind in
            MomentCaptureView(kind: kind)
        }
        .sheet(isPresented: $showingRecentlyDeleted) {
            RecentlyDeletedView(pages: pages.filter(\.isTrashed))
        }
        .safeAreaInset(edge: .bottom) {
            if let deletedPage {
                HStack {
                    Text("Moved to recently deleted")
                        .font(AppFont.body(13))
                    Spacer()
                    Button("Undo") { restore(deletedPage) }
                    Button {
                        self.deletedPage = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Dismiss undo")
                }
                .padding(16)
                .background(Color.paper)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pageSoftDeleted)) { notification in
            guard let id = notification.userInfo?["pageID"] as? PersistentIdentifier,
                  let page = pages.first(where: { $0.persistentModelID == id }),
                  page.growthKind != nil else { return }
            deletedPage = page
        }
        .onAppear(perform: purgeExpiredEntries)
        .alert("Couldn't save changes", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var momentsHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Braindump").font(AppFont.display(34))
                        Text("Your life, in little moments.")
                            .font(AppFont.body(14))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "sun.max")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.brandAccent)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text("You're doing better than you think.")
                        .font(AppFont.display(30))
                    Text("A new thing. A brave thing. A small thing that mattered. It all belongs here.")
                        .font(AppFont.body(15))
                    Button { captureKind = .win } label: {
                        Label("Save a little win", systemImage: "plus")
                            .font(AppFont.bodyBold(16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.brandAccent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save a moment")
                    .accessibilityIdentifier("capture-moment")
                    Text("One sentence, a photo, or your voice. No streaks. No catching up.")
                        .font(AppFont.body(12))
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.butter, in: RoundedRectangle(cornerRadius: 28))

                Button { selectedTab = .recaps } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 26, weight: .light))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Date.now.formatted(.dateTime.month(.wide))), lately.")
                                .font(AppFont.display(22))
                            Text("See the month you've been living.")
                                .font(AppFont.body(12))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14))
                    }
                    .padding(22)
                    .background(Color.lilac, in: RoundedRectangle(cornerRadius: 24))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open-recap")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Worth remembering").font(AppFont.display(24))
                        Spacer(minLength: 8)
                        Button { captureKind = .win } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24, weight: .light))
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Add another moment")
                    }
                    Picker("Show moments", selection: $filter) {
                        Text("All moments").tag(nil as GrowthKind?)
                        Text("Wins").tag(GrowthKind.win as GrowthKind?)
                        Text("Firsts").tag(GrowthKind.experience as GrowthKind?)
                        Text("Milestones").tag(GrowthKind.milestone as GrowthKind?)
                    }
                    .pickerStyle(.menu)
                    .font(AppFont.body(12))
                }

                if moments.isEmpty {
                    GrowthEmptyState(
                        title: "Nothing here yet.",
                        text: filter == nil ? "Save something you'd like to remember. It doesn't need to be a big occasion." : "No moments of this kind saved yet."
                    )
                } else {
                    LazyVGrid(columns: momentColumns(dynamicTypeSize), spacing: 14) {
                        ForEach(moments) { page in
                            NavigationLink(value: page) {
                                if let moment = GrowthMoment(page: page) {
                                    MomentCard(moment: moment)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                let deletedCount = pages.filter(\.isTrashed).count
                if deletedCount > 0 {
                    Button("Recently deleted (\(deletedCount))") { showingRecentlyDeleted = true }
                        .font(AppFont.body(13))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("recently-deleted-moments")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .foregroundStyle(.ink)
        .background(Color.paper)
    }

    private var goalsHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room to grow").font(AppFont.display(34))
                    Text("Not another to-do list. Just the things you'd like to make more room for.")
                        .font(AppFont.body(14))
                }
                Button { captureKind = .goal } label: {
                    Label("Plant a personal goal", systemImage: "plus")
                        .font(AppFont.bodyBold(15))
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(Color.sage, in: RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("add-goal")
                if goals.isEmpty {
                    GrowthEmptyState(title: "What would you like to try?", text: "Keep an intention here, then add moments along the way. No deadline needed.")
                }
                ForEach(goals) { goal in
                    NavigationLink(value: goal) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(goal.growthCategory.label, systemImage: "leaf")
                                .font(AppFont.body(12))
                            Text(goal.title).font(AppFont.display(25))
                            if !goal.paragraphs.isEmpty, goal.previewText != goal.title {
                                Text(goal.previewText)
                                    .font(AppFont.body(14))
                                    .lineLimit(3)
                            }
                            let count = pages.filter { !$0.isTrashed && $0.isMoment && $0.linkedGoalID == goal.uuid }.count
                            HStack {
                                Text("\(count) moment\(count == 1 ? "" : "s") along the way")
                                    .font(AppFont.bodyBold(12))
                                Spacer()
                                Image(systemName: "arrow.right").font(.system(size: 13))
                            }
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(goal.growthCategory.color.color, in: RoundedRectangle(cornerRadius: 26))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .foregroundStyle(.ink)
        .background(Color.paper)
    }

    private func restore(_ page: Page) {
        do {
            try page.restore(in: modelContext)
            deletedPage = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purgeExpiredEntries() {
        let expired = pages.filter { $0.isTrashed && ($0.daysUntilPermanentDelete ?? 1) <= 0 }
        guard !expired.isEmpty else { return }
        for page in expired { modelContext.delete(page) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct GoalDetailView: View {
    let goal: Page
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var pages: [Page]
    @State private var showingCapture = false

    private var steps: [Page] {
        pages.filter { !$0.isTrashed && $0.isMoment && $0.linkedGoalID == goal.uuid }
            .sorted { $0.eventDate > $1.eventDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Label(goal.growthCategory.label, systemImage: "leaf")
                        .font(AppFont.body(12))
                    Text(goal.title).font(AppFont.display(32))
                    if !goal.paragraphs.isEmpty, goal.previewText != goal.title {
                        Text(goal.previewText).font(AppFont.body(16))
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(goal.growthCategory.color.color, in: RoundedRectangle(cornerRadius: 26))
                Button { showingCapture = true } label: {
                    Label("Add a moment", systemImage: "plus")
                        .font(AppFont.bodyBold(14))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.sage, in: RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("add-goal-moment")
                if steps.isEmpty {
                    GrowthEmptyState(title: "No moments yet.", text: "Record something connected to this goal whenever it happens.")
                }
                LazyVGrid(columns: momentColumns(dynamicTypeSize), spacing: 14) {
                    ForEach(steps) { page in
                        NavigationLink {
                            PageView(page: page)
                        } label: {
                            if let moment = GrowthMoment(page: page) { MomentCard(moment: moment) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .foregroundStyle(.ink)
        .background(Color.paper)
        .toolbar {
            NavigationLink("Edit goal") { PageView(page: goal) }
        }
        .sheet(isPresented: $showingCapture) {
            MomentCaptureView(kind: .win, goal: goal)
        }
        .onChange(of: goal.isTrashed) { _, isTrashed in
            if isTrashed { dismiss() }
        }
    }
}

struct MomentCard: View {
    let moment: GrowthMoment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let data = moment.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Photo saved with this moment")
            } else {
                Image(systemName: moment.kind.symbol)
                    .font(.system(size: 30, weight: .light))
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
            }
            Text(moment.kind.label.uppercased())
                .font(AppFont.bodyBold(10))
            Text(moment.title.isEmpty ? "A moment worth keeping" : moment.title)
                .font(AppFont.display(20))
                .fixedSize(horizontal: false, vertical: true)
            if !moment.text.isEmpty, moment.text != moment.title {
                Text(moment.text).font(AppFont.body(12)).lineLimit(3)
            }
            Spacer(minLength: 4)
            Text("\(moment.date.formatted(.dateTime.month(.abbreviated).day())) · \(moment.category.label)")
                .font(AppFont.body(11))
        }
        .foregroundStyle(moment.category.color.textColor)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(moment.category.color.color, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct GrowthEmptyState: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(AppFont.display(23))
            Text(text).font(AppFont.body(14))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.butter, in: RoundedRectangle(cornerRadius: 24))
    }
}

func momentColumns(_ size: DynamicTypeSize) -> [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 14), count: size.isAccessibilitySize ? 1 : 2)
}
