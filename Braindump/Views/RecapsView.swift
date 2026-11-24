import SwiftUI
import SwiftData

struct RecapsView: View {
    @Query private var pages: [Page]
    @State private var month = Date.now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Your life, lately.")
                        .font(AppFont.display(34))
                    Text("A little reminder of the life you're building. Not a report card.")
                        .font(AppFont.body(14))
                    HStack(spacing: 8) {
                        Button { moveMonth(by: -1) } label: {
                            Image(systemName: "chevron.left").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Previous month")
                        Text(month.formatted(.dateTime.month(.wide).year()))
                            .font(AppFont.bodyBold(16))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Button { moveMonth(by: 1) } label: {
                            Image(systemName: "chevron.right").frame(width: 44, height: 44)
                        }
                        .disabled(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month))
                        .accessibilityLabel("Next month")
                    }
                    if let recap = MonthlyRecap(month: month, pages: pages) {
                        MonthlyRecapContent(recap: recap, pages: pages)
                    } else {
                        Text("Couldn't read this month's dates. Try selecting another month.")
                            .font(AppFont.body(14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .foregroundStyle(.ink)
            .background(Color.paper)
            .navigationTitle("Recaps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(.ink)
    }

    private func moveMonth(by offset: Int) {
        // Move from the month boundary so January 31 doesn't skip February.
        guard let start = Calendar.current.dateInterval(of: .month, for: month)?.start,
              let next = Calendar.current.date(byAdding: .month, value: offset, to: start) else { return }
        month = next
    }
}

private struct MonthlyRecapContent: View {
    let recap: MonthlyRecap
    let pages: [Page]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var reflection: GrowthReflection?
    @State private var requestID: UUID?
    @State private var isGenerating = false

    private struct Request: Equatable {
        let id: UUID?
        let moments: [GrowthMoment]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 16) {
                Text("YOUR MONTHLY RECAP")
                    .font(AppFont.bodyBold(11))
                Text("\(recap.interval.start.formatted(.dateTime.month(.wide))), lately.")
                    .font(AppFont.display(34))
                Text("A little more life.\nA little more you.")
                    .font(AppFont.body(18))
                Text("\(recap.moments.count) moment\(recap.moments.count == 1 ? "" : "s") worth remembering.")
                    .font(AppFont.body(14))
                if Calendar.current.isDate(recap.interval.start, equalTo: .now, toGranularity: .month) {
                    Text("Your month so far")
                        .font(AppFont.bodyBold(12))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lilac, in: RoundedRectangle(cornerRadius: 28))

            if recap.moments.isEmpty {
                GrowthEmptyState(title: "No moments this month.", text: "New entries will appear here. You can also save a moment from an earlier day.")
            } else {
                LazyVGrid(columns: momentColumns(dynamicTypeSize), spacing: 12) {
                    stat(recap.wins, "Little wins", color: .butter)
                    stat(recap.experiences, "New experiences", color: .sky)
                    stat(recap.milestones, "Personal milestones", color: .blush)
                    stat(recap.experienceDays, "Days trying something new", color: .sage)
                }
                Text("From your saved entries, not everything you did.")
                    .font(AppFont.body(12))
                    .foregroundStyle(.dune)

                Text("What showed up").font(AppFont.display(28))
                VStack(spacing: 14) {
                    ForEach(recap.categories, id: \.category) { item in
                        HStack {
                            Circle().fill(item.category.color.textColor).frame(width: 6, height: 6)
                            Text(item.category.label).font(AppFont.body(14))
                            Spacer()
                            Text("\(item.count)").font(AppFont.body(12)).foregroundStyle(.dune)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(20)
                .background(Color.stone, in: RoundedRectangle(cornerRadius: 24))

                Text("A month in moments").font(AppFont.display(26))
                LazyVGrid(columns: momentColumns(dynamicTypeSize), spacing: 14) {
                    ForEach(recap.moments) { moment in
                        if let page = pages.first(where: { $0.uuid == moment.id }) {
                            NavigationLink {
                                PageView(page: page)
                            } label: {
                                MomentCard(moment: moment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("A reflection on your month", systemImage: "sparkles")
                        .font(AppFont.display(24))
                    Text(reflection?.text ?? recap.offlineReflection)
                        .font(AppFont.body(16))
                        .lineSpacing(4)
                    Text(reflection?.isGenerated == true ? "AI reflection · generated on this device" : "Record-based summary · not AI")
                        .font(AppFont.body(11))
                        .foregroundStyle(.dune)
                    if let reflection {
                        Text(reflection.explanation).font(AppFont.body(12)).foregroundStyle(.dune)
                    } else {
                        Text("An optional reflection uses your writing on this device. Photos aren't included.")
                            .font(AppFont.body(12))
                            .foregroundStyle(.dune)
                    }
                    if isGenerating {
                        ProgressView("Reflecting on your moments...")
                            .font(AppFont.body(13))
                    } else {
                        Button(reflection == nil ? "Ask for an AI reflection" : "Try AI reflection again") {
                            requestID = UUID()
                        }
                        .font(AppFont.body(14))
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("generate-reflection")
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mist, in: RoundedRectangle(cornerRadius: 26))
            }
        }
        .task(id: Request(id: requestID, moments: recap.moments)) {
            reflection = nil
            isGenerating = false
            guard requestID != nil else { return }
            isGenerating = true
            let result = await GrowthReflector.reflect(on: recap)
            guard !Task.isCancelled else { return }
            reflection = result
            isGenerating = false
        }
        .onChange(of: recap.moments) { requestID = nil }
    }

    private func stat(_ count: Int, _ label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(count)").font(AppFont.display(38))
            Text(label).font(AppFont.body(13))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}
