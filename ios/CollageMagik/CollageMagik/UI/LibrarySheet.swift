import AVKit
import SwiftUI

/// My Library: the designs in progress (drafts) and every collage you have exported, stored on this iPhone only.
struct LibrarySheet: View {
    @Environment(LibraryStore.self) private var library
    @Environment(CollageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: LibraryEntry?
    @State private var pendingDelete: LibraryEntry?
    @State private var pendingDraftDelete: DraftSummary?
    @State private var detent: PresentationDetent = .medium
    /// Only collages or only carousels (the Library tab's top tabs); nil shows both.
    var kind: EditMode? = nil
    /// Shown inside Home's Library tab instead of as a sheet: no Done button, and the theme shows through.
    var embedded = false

    private var drafts: [DraftSummary] { store.drafts.filter { kind == nil || $0.mode == kind } }
    private var entries: [LibraryEntry] { library.entries.filter { kind == nil || $0.isCarousel == (kind == .carousel) } }
    private var emptyTitle: String { kind == .carousel ? String(localized: "No carousels yet") : String(localized: "No collages yet") }

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .top)]

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty && drafts.isEmpty {
                    ContentUnavailableView(
                        kind == nil ? String(localized: "Nothing here yet") : emptyTitle,
                        systemImage: kind == .carousel ? "rectangle.split.3x1" : "photo.stack",
                        description: Text(String(localized: "Designs you're working on are saved here as drafts, and the ones you export are kept here too. All on this iPhone only; nothing is uploaded."))
                    )
                } else {
                    ScrollView {
                        if !drafts.isEmpty { draftsSection }
                        if !entries.isEmpty && !drafts.isEmpty { sectionHeader(String(localized: "Exported"), count: entries.count) }
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(entries) { entry in
                                Button { selected = entry } label: { LibraryCell(entry: entry) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        ShareLink(item: library.url(for: entry)) { Label(String(localized: "Share"), systemImage: "square.and.arrow.up") }
                                        Button(role: .destructive) { pendingDelete = entry } label: { Label(String(localized: "Delete"), systemImage: "trash") }
                                    }
                                    .accessibilityLabel(entry.isCarousel ? String(localized: "Carousel of \(entry.slideCount) slides") : (entry.isVideo ? String(localized: "Video collage, \(entry.localizedFormatLabel)") : String(localized: "Picture collage, \(entry.localizedFormatLabel)")))
                            }
                        }
                        .padding(12)

                        if !entries.isEmpty {
                        Text(String(localized: "Saved designs: \(entries.count) · \(ByteCountFormatter.string(fromByteCount: library.totalBytes, countStyle: .file)) on this iPhone. Touch and hold a design to share or delete it."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                        }
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                }
            }
            .navigationTitle(String(localized: "My Library"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selected) { LibraryDetail(entry: $0).toolbar(.visible, for: .navigationBar) }
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Done"), systemImage: "checkmark") { dismiss() } }
                }
            }
            .toolbar(embedded ? .hidden : .automatic, for: .navigationBar)
            .containerBackground(embedded ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.background), for: .navigation)
            .confirmationDialog(String(localized: "Delete this collage?"), isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button(String(localized: "Delete"), role: .destructive) {
                    if let e = pendingDelete { withAnimation { library.remove(e) } }
                    pendingDelete = nil
                }
            } message: {
                Text(String(localized: "It is removed from My Library. A copy you saved to Photos is not affected."))
            }
            .confirmationDialog(String(localized: "Delete this draft?"), isPresented: Binding(
                get: { pendingDraftDelete != nil }, set: { if !$0 { pendingDraftDelete = nil } }
            ), titleVisibility: .visible) {
                Button(String(localized: "Delete draft"), role: .destructive) {
                    if let d = pendingDraftDelete { withAnimation { store.deleteDraft(d.id) } }
                    pendingDraftDelete = nil
                }
            } message: {
                Text(pendingDraftDelete?.id == store.draftId
                     ? String(localized: "This is the design that's open now. It's cleared and can't be brought back. Collages you exported stay.")
                     : String(localized: "The design and its copies of your photos and videos are removed from this iPhone. Your Photos library is not affected."))
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // A single collage needs the room: its player and the Share / Save / Delete buttons.
        .onChange(of: selected) { _, new in if new != nil { withAnimation(.smooth) { detent = .large } } }
    }
}

extension LibrarySheet {
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Text("\(count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var draftsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "Drafts"), count: drafts.count)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(drafts) { d in
                        Button { open(d) } label: { DraftCell(draft: d, isOpen: d.id == store.draftId) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { open(d) } label: { Label(d.id == store.draftId ? String(localized: "Keep editing") : String(localized: "Open"), systemImage: "pencil") }
                                Button(role: .destructive) { pendingDraftDelete = d } label: { Label(String(localized: "Delete draft"), systemImage: "trash") }
                            }
                            .accessibilityLabel(String(localized: "Draft, \(d.format.label), \(d.summary), edited \(d.updatedAt.formatted(.relative(presentation: .named)))"))
                            .accessibilityHint(d.id == store.draftId ? String(localized: "Open now") : String(localized: "Opens this design"))
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollClipDisabled()
            Text(String(localized: "Saved as you edit. Tap a draft to keep working on it; touch and hold to delete it."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private func open(_ d: DraftSummary) {
        dismiss()
        // from Home, opening a draft also opens the editor
        store.editorOpen = true
        guard d.id != store.draftId else { return }
        Task { await store.openDraft(d.id) }
    }
}

private struct DraftCell: View {
    let draft: DraftSummary
    let isOpen: Bool
    private let height: CGFloat = 160
    /// Story drafts are narrow: the card stays wide enough for its two lines of text.
    private var width: CGFloat { min(280, max(124, height * draft.aspect)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .frame(width: width, height: height)
                .overlay {
                    AsyncFileImage(url: draft.thumbURL, maxSide: max(width, height), contentMode: .fill,
                                   version: "\(draft.updatedAt.timeIntervalSince1970)")
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isOpen ? Color.brand : .clear, lineWidth: 2.5)
                }
                .overlay(alignment: .topLeading) {
                    if isOpen {
                        Text(String(localized: "Open now"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(Color.brand.opacity(0.7)), in: .capsule)
                            .padding(6)
                    }
                }
            Text(draft.updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(draft.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct LibraryCell: View {
    @Environment(LibraryStore.self) private var library
    let entry: LibraryEntry

    var body: some View {
        Color.clear
            .aspectRatio(Double(entry.width) / Double(entry.height), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if let img = library.thumbnail(for: entry) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if entry.isVideo {
                    Label(formatTime(entry.duration), systemImage: "play.fill")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .capsule)
                        .padding(6)
                } else if entry.isCarousel {
                    Label(String(localized: "\(entry.slideCount)"), systemImage: "square.stack.fill")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .capsule)
                        .padding(6)
                }
            }
    }
}

/// One collage: play or view it, share it, save it to Photos, or delete it.
private struct LibraryDetail: View {
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    let entry: LibraryEntry

    @State private var player: AVPlayer?
    @State private var saved = false
    @State private var saveError: Error?
    @State private var confirmDelete = false

    private var url: URL { library.url(for: entry) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if entry.isCarousel {
                    ScrollView(.horizontal, showsIndicators: false) {
                        // up to 20 slides: each is decoded at the size shown, only when it scrolls into view
                        LazyHStack(spacing: 6) {
                            ForEach(Array(library.urls(for: entry).enumerated()), id: \.offset) { i, u in
                                Group {
                                    AsyncFileImage(url: u, maxSide: 340)
                                        .aspectRatio(Double(entry.width) / Double(max(1, entry.height)), contentMode: .fit)
                                        .frame(height: 340)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .overlay(alignment: .topLeading) {
                                            Text("\(i + 1)")
                                                .font(.caption2.weight(.bold).monospacedDigit())
                                                .padding(.horizontal, 7).padding(.vertical, 3)
                                                .glassEffect(.regular, in: .capsule)
                                                .padding(6)
                                        }
                                }
                            }
                        }
                    }
                    .scrollClipDisabled()
                } else {
                    Group {
                        if entry.isVideo, let player {
                            VideoPlayer(player: player)
                        } else if FileManager.default.fileExists(atPath: url.path) {
                            AsyncFileImage(url: url, maxSide: 460)
                        } else {
                            ContentUnavailableView(String(localized: "Can't open this collage"), systemImage: "exclamationmark.triangle")
                        }
                    }
                    .aspectRatio(Double(entry.width) / Double(entry.height), contentMode: .fit)
                    .frame(maxHeight: 460)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                VStack(spacing: 4) {
                    Text(entry.createdAt, format: .dateTime.day().month(.wide).year().hour().minute())
                        .font(.headline)
                    Text(entry.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        Group {
                            if entry.isCarousel {
                                ShareLink(items: library.urls(for: entry)) {
                                    Label(String(localized: "Share all \(entry.slideCount) slides"), systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                            } else {
                                ShareLink(item: url) {
                                    Label(String(localized: "Share"), systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                            }
                        }
                        .buttonStyle(.glassProminent)

                        Button {
                            Task {
                                do {
                                    if entry.isCarousel {
                                        try await PhotoSaver.saveAll(urls: library.urls(for: entry))
                                    } else {
                                        try await PhotoSaver.save(url: url, isVideo: entry.isVideo)
                                    }
                                    withAnimation { saved = true }
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } catch {
                                    saveError = error
                                }
                            }
                        } label: {
                            Label(saved ? String(localized: "Saved to Photos") : (entry.isCarousel ? String(localized: "Save all to Photos") : String(localized: "Save to Photos")), systemImage: saved ? "checkmark" : "photo.badge.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .disabled(saved)

                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label(String(localized: "Delete"), systemImage: "trash").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                }
                if let saveError {
                    SaveFailureNote(error: saveError)
                }
            }
            .padding(16)
        }
        .navigationTitle(entry.isCarousel ? String(localized: "Carousel") : (entry.isVideo ? String(localized: "Video") : String(localized: "Picture")))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if entry.isVideo, player == nil { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause() }
        .confirmationDialog(String(localized: "Delete this collage?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(String(localized: "Delete"), role: .destructive) {
                player?.pause()
                player = nil
                library.remove(entry)
                dismiss()
            }
        } message: {
            Text(String(localized: "It is removed from My Library. A copy you saved to Photos is not affected."))
        }
    }
}
