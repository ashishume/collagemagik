import AVKit
import SwiftUI

/// My Library: every collage you have exported, stored on this iPhone only.
struct LibrarySheet: View {
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var selected: LibraryEntry?
    @State private var pendingDelete: LibraryEntry?
    @State private var detent: PresentationDetent = .medium

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .top)]

    var body: some View {
        NavigationStack {
            Group {
                if library.entries.isEmpty {
                    ContentUnavailableView(
                        "No collages yet",
                        systemImage: "photo.stack",
                        description: Text("Collages you export are kept here, on this iPhone only. Nothing is uploaded.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(library.entries) { entry in
                                Button { selected = entry } label: { LibraryCell(entry: entry) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        ShareLink(item: library.url(for: entry)) { Label("Share", systemImage: "square.and.arrow.up") }
                                        Button(role: .destructive) { pendingDelete = entry } label: { Label("Delete", systemImage: "trash") }
                                    }
                                    .accessibilityLabel(entry.isCarousel ? "Carousel of \(entry.slideCount) slides" : "\(entry.isVideo ? "Video" : "Picture") collage, \(entry.formatLabel)")
                            }
                        }
                        .padding(12)

                        Text("\(library.entries.count) \(library.entries.count == 1 ? "collage" : "collages") · \(ByteCountFormatter.string(fromByteCount: library.totalBytes, countStyle: .file)) on this iPhone. Touch and hold a collage to share or delete it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                }
            }
            .navigationTitle("My Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selected) { LibraryDetail(entry: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
            .confirmationDialog("Delete this collage?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let e = pendingDelete { withAnimation { library.remove(e) } }
                    pendingDelete = nil
                }
            } message: {
                Text("It is removed from My Library. A copy you saved to Photos is not affected.")
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // A single collage needs the room: its player and the Share / Save / Delete buttons.
        .onChange(of: selected) { _, new in if new != nil { withAnimation(.smooth) { detent = .large } } }
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
                    Label("\(entry.slideCount)", systemImage: "square.stack.fill")
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
                        HStack(spacing: 6) {
                            ForEach(Array(library.urls(for: entry).enumerated()), id: \.offset) { i, u in
                                if let img = UIImage(contentsOfFile: u.path) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
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
                        } else if let img = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: img).resizable().scaledToFit()
                        } else {
                            ContentUnavailableView("Can't open this collage", systemImage: "exclamationmark.triangle")
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
                                    Label("Share all \(entry.slideCount) slides", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                            } else {
                                ShareLink(item: url) {
                                    Label("Share", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
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
                            Label(saved ? "Saved to Photos" : (entry.isCarousel ? "Save all to Photos" : "Save to Photos"), systemImage: saved ? "checkmark" : "photo.badge.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .disabled(saved)

                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete", systemImage: "trash").frame(maxWidth: .infinity)
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
        .navigationTitle(entry.isCarousel ? "Carousel" : (entry.isVideo ? "Video" : "Picture"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if entry.isVideo, player == nil { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause() }
        .confirmationDialog("Delete this collage?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                player?.pause()
                player = nil
                library.remove(entry)
                dismiss()
            }
        } message: {
            Text("It is removed from My Library. A copy you saved to Photos is not affected.")
        }
    }
}
