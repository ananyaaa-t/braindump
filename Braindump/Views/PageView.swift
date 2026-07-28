import SwiftUI
import SwiftData
import FoundationModels

struct PageView: View {
    @Bindable var page: Page
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @StateObject private var voiceRecorder = VoiceRecorder()
    @StateObject private var editorController = RichTextEditorController()
    @State private var showingInfo = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            page.color.color.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear.frame(height: 28)

                    TextField("untitled", text: $page.title, axis: .vertical)
                        .font(AppFont.display(32))
                        .foregroundStyle(.ink)
                        .focused($titleFocused)
                        .onChange(of: page.title) { page.updatedAt = .now }

                    Text("edited \(page.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppFont.body(12))
                        .foregroundStyle(.dune)

                    Divider()
                        .overlay(page.color.color.darkerTint())

                    ZStack(alignment: .topLeading) {
                        if isBodyEmpty {
                            Text("write something…")
                                .font(AppFont.body(18))
                                .foregroundStyle(.dune)
                                .allowsHitTesting(false)
                        }
                        RichTextEditor(page: page, controller: editorController)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: 44)
                }
                .padding(20)
                .padding(.top, 8)
            }

            backButton
            topRightControls
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if voiceRecorder.isRecording || !voiceRecorder.transcript.isEmpty {
                    listeningBanner
                }
                if let error = voiceRecorder.errorMessage {
                    Text(error)
                        .font(AppFont.body(12))
                        .foregroundStyle(.dune)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .background(page.color.color)
                }
                controlBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingInfo) {
            InfoSheet(page: page)
        }
        .onChange(of: voiceRecorder.isRecording) { _, isRecording in
            if !isRecording { commitDictation() }
        }
    }

    private var isBodyEmpty: Bool {
        page.paragraphs.allSatisfy { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(.dune)
                .padding(12)
        }
        .accessibilityLabel("Back")
        .padding(.leading, 8)
        .padding(.top, 4)
    }

    private var topRightControls: some View {
        HStack(spacing: 4) {
            formatMenu

            Button {
                voiceRecorder.toggle()
            } label: {
                Image(systemName: "mic")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(voiceRecorder.isRecording ? Color.ink : Color.dune)
                    .padding(12)
            }
            .accessibilityLabel(voiceRecorder.isRecording ? "Stop dictation" : "Start dictation")

            Button {
                showingInfo = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.dune)
                    .padding(12)
            }
            .accessibilityLabel("Page details")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 4)
        .padding(.top, 4)
    }

    private var formatMenu: some View {
        Menu {
            Section {
                ForEach(ParagraphStyle.allCases, id: \.self) { style in
                    Button {
                        editorController.apply(kind: .text, style: style)
                    } label: {
                        if editorController.currentKind() == .text && editorController.currentStyle() == style {
                            Label(style.label, systemImage: "checkmark")
                        } else {
                            Text(style.label)
                        }
                    }
                }
            }
            Section {
                Button {
                    editorController.apply(kind: .bullet, style: .body)
                } label: {
                    if editorController.currentKind() == .bullet {
                        Label("Bullet", systemImage: "checkmark")
                    } else {
                        Text("Bullet")
                    }
                }
                Button {
                    editorController.apply(kind: .checklist, style: .body)
                } label: {
                    if editorController.currentKind() == .checklist {
                        Label("Checklist", systemImage: "checkmark")
                    } else {
                        Text("Checklist")
                    }
                }
            }
            if editorController.currentKind() == .checklist {
                Section {
                    Button {
                        editorController.toggleCurrentChecklistItem()
                    } label: {
                        Text("Toggle Done")
                    }
                }
            }
            Section {
                Button {
                    editorController.toggleBold()
                } label: {
                    if editorController.currentBold() {
                        Label("Bold", systemImage: "checkmark")
                    } else {
                        Text("Bold")
                    }
                }
                Button {
                    editorController.toggleItalic()
                } label: {
                    if editorController.currentItalic() {
                        Label("Italic", systemImage: "checkmark")
                    } else {
                        Text("Italic")
                    }
                }
                Button {
                    editorController.toggleUnderline()
                } label: {
                    if editorController.currentUnderline() {
                        Label("Underline", systemImage: "checkmark")
                    } else {
                        Text("Underline")
                    }
                }
            }
        } label: {
            Text("Aa")
                .font(AppFont.body(15))
                .foregroundStyle(.dune)
                .padding(12)
        }
        .accessibilityLabel("Text style")
    }

    private var listeningBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(voiceRecorder.isRecording ? "listening…" : "tap the mic to keep dictating")
                .font(AppFont.body(12))
                .foregroundStyle(.dune)
            Text(voiceRecorder.transcript.isEmpty ? " " : voiceRecorder.transcript)
                .font(AppFont.body(16))
                .foregroundStyle(.ink)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(page.color.color.darkerTint(by: 0.05))
    }

    private func commitDictation() {
        let text = voiceRecorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let nextOrder = (page.paragraphs.map(\.sortOrder).max() ?? -1) + 1
        let paragraph = Paragraph(text: text, sortOrder: nextOrder)
        paragraph.page = page
        page.paragraphs.append(paragraph)
        page.updatedAt = .now
        voiceRecorder.transcript = ""
    }

    private var controlBar: some View {
        HStack(spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(PageColor.allCases) { option in
                        ColorDot(color: option.color, isSelected: page.color == option) {
                            withAnimation(.easeInOut(duration: 0.15)) { page.color = option }
                        }
                        .accessibilityLabel("\(option.rawValue.capitalized) color")
                        .accessibilityAddTraits(page.color == option ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.vertical, 4)
            }

            Button(role: .destructive) {
                page.softDelete()
                NotificationCenter.default.post(
                    name: .pageSoftDeleted,
                    object: nil,
                    userInfo: ["pageID": page.persistentModelID, "title": page.title]
                )
                dismiss()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.dune)
            }
            .accessibilityLabel("Delete page")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(page.color.color)
        .overlay(alignment: .top) {
            Rectangle().fill(page.color.color.darkerTint()).frame(height: 0.5)
        }
    }
}

private struct ColorDot: View {
    let color: Color
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.ink.opacity(isSelected ? 0.6 : 0), lineWidth: 1.5)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct InfoSheet: View {
    @Bindable var page: Page
    @Environment(\.dismiss) private var dismiss
    @State private var overviewText: String?
    @State private var overviewIsGenerated = false
    @State private var isGeneratingOverview = false
    @State private var tagsAreGenerated = false
    @State private var aiUnavailableReason: String?
    @State private var suggestedActionItems: [String] = []
    @State private var isFindingActionItems = false
    @State private var didInsertActionItems = false

    private var chipColor: Color { page.color.color.darkerTint(by: 0.08) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                lastEditedRow
                tagsSection
                overviewSection
                actionItemsSection
                if let aiUnavailableReason {
                    Text(aiUnavailableReason)
                        .font(AppFont.body(12))
                        .foregroundStyle(.dune)
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(page.color.color.ignoresSafeArea())
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
            .toolbarBackground(page.color.color, for: .navigationBar)
        }
        .tint(.ink)
        .task {
            if #available(iOS 26.0, *) {
                await loadAllGenerativeContent()
            } else {
                aiUnavailableReason = "Apple Intelligence needs iOS 26 or later."
                isGeneratingOverview = true
                loadFallbackContent()
                isGeneratingOverview = false
            }
        }
        .presentationDetents([.medium])
    }

    /// Fallback path used on OS versions below 26, or when the model turns
    /// out to be unavailable at runtime: keyword-heuristic tags and the
    /// extractive summarizer. No fallback for action items — see
    /// `NoteAnalyzer.extractActionItems`.
    private func loadFallbackContent() {
        if page.tags.isEmpty {
            page.tags = NoteAnalyzer.suggestedTags(for: page)
            tagsAreGenerated = false
        }
        overviewText = NoteAnalyzer.summary(for: page)
        overviewIsGenerated = false
    }

    /// Drives tags, overview, and action-item suggestions off of one shared,
    /// prewarmed `LanguageModelSession` (see `NoteAnalyzer.makeSession`)
    /// instead of a session per call. Falls back to the heuristics (and
    /// explains why, via `aiUnavailableReason`) if the model isn't actually
    /// usable despite the OS supporting it in principle.
    @available(iOS 26.0, *)
    private func loadAllGenerativeContent() async {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            aiUnavailableReason = NoteAnalyzer.unavailabilityMessage(for: availability)
            isGeneratingOverview = true
            loadFallbackContent()
            isGeneratingOverview = false
            return
        }

        let session = NoteAnalyzer.makeSession()

        if page.tags.isEmpty {
            if let generated = await NoteAnalyzer.generativeTags(for: page, session: session) {
                page.tags = generated
                tagsAreGenerated = true
            } else {
                page.tags = NoteAnalyzer.suggestedTags(for: page)
                tagsAreGenerated = false
                noteGenerationFailure()
            }
        }

        isGeneratingOverview = true
        if let generated = await NoteAnalyzer.generativeOverview(for: page, session: session) {
            overviewText = generated
            overviewIsGenerated = true
        } else {
            overviewText = NoteAnalyzer.summary(for: page)
            overviewIsGenerated = false
            noteGenerationFailure()
        }
        isGeneratingOverview = false

        isFindingActionItems = true
        suggestedActionItems = await NoteAnalyzer.extractActionItems(for: page, session: session) ?? []
        isFindingActionItems = false
    }

    /// Surfaces an explanation the first time a generative call comes back
    /// nil despite `SystemLanguageModel.default.availability` reporting
    /// `.available` — e.g. the on-device content-safety model asset isn't
    /// actually loadable (a real, observed Simulator failure mode:
    /// `FoundationModels.LanguageModelSession.GenerationError` wrapping a
    /// `ModelManagerServices.ModelManagerError`). Without this, a page just
    /// silently shows the same heuristic output as when Apple Intelligence
    /// is unavailable, with no indication anything went wrong.
    private func noteGenerationFailure() {
        guard aiUnavailableReason == nil else { return }
        aiUnavailableReason = "Apple Intelligence didn't respond just now, so this is showing simpler, offline suggestions instead."
    }

    /// Appends the suggested action items to the page as new (unchecked)
    /// checklist paragraphs and bumps `updatedAt` so `RichTextEditor`
    /// notices the model changed underneath it and rebuilds from it the
    /// next time this sheet is dismissed.
    private func addActionItemsToPage() {
        let existing = page.paragraphs.sorted { $0.sortOrder < $1.sortOrder }
        var nextOrder = (existing.last?.sortOrder ?? -1) + 1
        for item in suggestedActionItems {
            let paragraph = Paragraph(text: item, kind: .checklist, style: .body, isChecked: false, sortOrder: nextOrder)
            paragraph.page = page
            page.paragraphs.append(paragraph)
            nextOrder += 1
        }
        page.updatedAt = .now
        suggestedActionItems = []
        didInsertActionItems = true
    }

    @ViewBuilder
    private var actionItemsSection: some View {
        if isFindingActionItems {
            VStack(alignment: .leading, spacing: 6) {
                Text("action items · on-device AI")
                    .font(AppFont.body(11))
                    .foregroundStyle(.dune)
                Text("looking…")
                    .font(AppFont.body(15))
                    .foregroundStyle(.dune)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chipColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if !suggestedActionItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("action items · on-device AI")
                    .font(AppFont.body(11))
                    .foregroundStyle(.dune)
                ForEach(suggestedActionItems, id: \.self) { item in
                    Text("•  \(item)")
                        .font(AppFont.body(14))
                        .foregroundStyle(.ink)
                }
                Button {
                    addActionItemsToPage()
                } label: {
                    Label("Add to page as checklist", systemImage: "checklist")
                        .font(AppFont.body(13))
                }
                .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chipColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if didInsertActionItems {
            Text("Added to page.")
                .font(AppFont.body(12))
                .foregroundStyle(.dune)
        }
    }

    private var lastEditedRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.dune)
            VStack(alignment: .leading, spacing: 2) {
                Text("last edited")
                    .font(AppFont.body(11))
                    .foregroundStyle(.dune)
                Text(page.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.body(15))
                    .foregroundStyle(.ink)
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tagsAreGenerated ? "tags · on-device AI" : "tags")
                .font(AppFont.body(11))
                .foregroundStyle(.dune)

            if page.tags.isEmpty {
                Text("no tags yet")
                    .font(AppFont.body(13))
                    .foregroundStyle(.dune)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(page.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button {
                                    page.tags.removeAll { $0 == tag }
                                    tagsAreGenerated = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .accessibilityLabel("Remove \(tag) tag")
                            }
                            .font(AppFont.body(13))
                            .foregroundStyle(.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(chipColor)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            let remaining = NoteTag.allCases.map(\.rawValue).filter { !page.tags.contains($0) }
            if !remaining.isEmpty {
                Menu {
                    ForEach(remaining, id: \.self) { tag in
                        Button(tag) {
                            page.tags.append(tag)
                            tagsAreGenerated = false
                        }
                    }
                } label: {
                    Label("add tag", systemImage: "plus")
                        .font(AppFont.body(13))
                        .foregroundStyle(.dune)
                }
            }
        }
    }

    @ViewBuilder
    private var overviewSection: some View {
        if isGeneratingOverview {
            VStack(alignment: .leading, spacing: 6) {
                Text("overview")
                    .font(AppFont.body(11))
                    .foregroundStyle(.dune)
                Text("thinking…")
                    .font(AppFont.body(15))
                    .foregroundStyle(.dune)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chipColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let overviewText {
            VStack(alignment: .leading, spacing: 6) {
                Text(overviewIsGenerated ? "overview · on-device AI" : "overview")
                    .font(AppFont.body(11))
                    .foregroundStyle(.dune)
                Text(overviewText)
                    .font(AppFont.body(15))
                    .foregroundStyle(.ink)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chipColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    let page = Page(title: "A quiet page", color: .sage)
    return NavigationStack {
        PageView(page: page)
    }
    .modelContainer(for: [Page.self, Paragraph.self], inMemory: true)
}
