import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import WidgetKit

struct MomentCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var pages: [Page]
    @StateObject private var recorder = VoiceRecorder()
    @State private var kind: GrowthKind
    @State private var category = GrowthCategory.everyday
    @State private var text = ""
    @State private var date = Date.now
    @State private var goalID: UUID?
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var loadingPhoto = false
    @State private var errorMessage: String?

    init(kind: GrowthKind, goal: Page? = nil) {
        _kind = State(initialValue: kind)
        _goalID = State(initialValue: goal?.uuid)
        _category = State(initialValue: goal?.growthCategory ?? .everyday)
    }

    private var goals: [Page] {
        pages.filter { !$0.isTrashed && $0.growthKind == .goal }.sorted { $0.title < $1.title }
    }

    private var canSave: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (photoData != nil && kind != .goal))
            && !loadingPhoto && !recorder.isRecording
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(kind == .goal ? "Something you'd like to try." : "What would you like to remember?")
                        .font(AppFont.display(29))
                    Text(kind == .goal ? "Keep the intention. Add moments as they happen." : "A sentence, a photo, or a voice note.")
                        .font(AppFont.body(14))
                        .foregroundStyle(.dune)
                    if kind != .goal {
                        Picker("Moment type", selection: $kind) {
                            ForEach(GrowthKind.allCases.filter { $0 != .goal }) {
                                Text($0.label).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    TextField(kind == .goal ? "I'd like to..." : "It started with...", text: $text, axis: .vertical)
                        .font(AppFont.body(18))
                        .lineLimit(3...8)
                        .padding(16)
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityIdentifier("moment-text")
                    Button {
                        recorder.toggle()
                    } label: {
                        Label(recorder.isRecording ? "Stop dictation" : "Dictate", systemImage: recorder.isRecording ? "stop.circle" : "mic")
                            .font(AppFont.body(14))
                    }
                    if recorder.isRecording {
                        Text(recorder.transcript.isEmpty ? "Listening..." : recorder.transcript)
                            .font(AppFont.body(15))
                        Text("Tap Stop dictation before saving. Voice is transcribed, not stored as audio.")
                            .font(AppFont.body(12))
                    }
                    if let error = recorder.errorMessage {
                        Text(error).font(AppFont.body(13)).foregroundStyle(.ink)
                    }

                    Divider()
                    Picker("Category", selection: $category) {
                        ForEach(GrowthCategory.allCases) { Text($0.label).tag($0) }
                    }
                    .font(AppFont.body(15))

                    if kind != .goal {
                        DatePicker("When it happened", selection: $date, in: ...Date.now, displayedComponents: .date)
                            .font(AppFont.body(14))
                        if !goals.isEmpty {
                            Picker("Personal goal", selection: $goalID) {
                                Text("No linked goal").tag(nil as UUID?)
                                ForEach(goals) { Text($0.title).tag($0.uuid as UUID?) }
                            }
                            .font(AppFont.body(14))
                        }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(photoData == nil ? "Add a photo (optional)" : "Change photo", systemImage: "photo")
                                .font(AppFont.body(14))
                        }
                        if loadingPhoto { ProgressView("Loading photo...") }
                        if let photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            Button("Remove photo") {
                                self.photoData = nil
                                photoItem = nil
                            }
                            .font(AppFont.body(13))
                        }
                    }
                    Text("Saved on this device.")
                        .font(AppFont.body(12))
                        .foregroundStyle(.dune)
                }
                .padding(22)
            }
            .foregroundStyle(.ink)
            .background(category.color.color)
            .navigationTitle(kind == .goal ? "New goal" : "New moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("save-moment")
                }
            }
        }
        .tint(.ink)
        .onChange(of: recorder.isRecording) { _, recording in
            guard !recording else { return }
            let transcript = recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                text += (text.isEmpty ? "" : "\n") + transcript
                recorder.transcript = ""
            }
        }
        .onDisappear { recorder.stop() }
        .task(id: photoItem) { await loadPhoto() }
        .alert("Couldn't save this moment", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    @MainActor
    private func loadPhoto() async {
        guard let photoItem else {
            loadingPhoto = false
            return
        }
        loadingPhoto = true
        defer {
            if self.photoItem == photoItem { loadingPhoto = false }
        }
        do {
            let data = try await photoItem.loadTransferable(type: Data.self)
            try Task.checkCancellation()
            guard let data, let image = UIImage(data: data) else {
                errorMessage = "That photo couldn't be opened. Choose another image."
                return
            }
            let scale = min(1, 1600 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
                errorMessage = "That photo couldn't be saved. Choose another image."
                return
            }
            photoData = jpeg
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Couldn't load the photo: \(error.localizedDescription)"
        }
    }

    private func save() {
        guard canSave else { return }
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = content.isEmpty ? "A photo worth keeping" : String(content.prefix(100))
        let page = Page(title: title, color: category.color)
        page.growthKind = kind
        page.growthCategory = category
        page.occurredAt = kind == .goal ? .now : date
        page.linkedGoalID = kind == .goal ? nil : goalID
        page.photoData = kind == .goal ? nil : photoData
        if !content.isEmpty {
            let paragraph = Paragraph(text: content)
            paragraph.page = page
            page.paragraphs.append(paragraph)
        }
        modelContext.insert(page)
        do {
            try modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            dismiss()
        } catch {
            modelContext.delete(page)
            errorMessage = error.localizedDescription
        }
    }
}
