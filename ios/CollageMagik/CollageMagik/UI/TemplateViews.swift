import SwiftUI

/// A template's picture and name. The picture is drawn by the real renderer, with the person's pictures when given.
struct TemplateCard: View {
    let template: DesignTemplate
    var pictures: [MediaItem] = []
    var height: CGFloat = 170
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var image: UIImage?
    @State private var motionFrames: [UIImage] = []

    private var showsMotion: Bool {
        template.isLiving && pictures.isEmpty && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.06))
                    if showsMotion && !motionFrames.isEmpty {
                        TimelineView(.periodic(from: .now, by: 0.16)) { context in
                            let offset = Int(context.date.timeIntervalSinceReferenceDate / 0.16)
                            artwork(motionFrames[offset % motionFrames.count])
                        }
                    } else if let img = image ?? TemplatePreview.cached(template, pictures: pictures) {
                        artwork(img)
                    }
                }
                .frame(height: height)
                .overlay {
                    if template.category == .video && !template.isLiving {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                    }
                }
                .task(id: showsMotion) {
                    guard showsMotion, motionFrames.isEmpty else { return }
                    motionFrames = await TemplatePreview.motionFrames(template)
                }
                // drawn after the card is on screen, so opening a list of 60+ templates never waits for all of them
                .task(id: pictures.map(\.id)) {
                    guard TemplatePreview.cached(template, pictures: pictures) == nil else { return }
                    await Task.yield()
                    let img = TemplatePreview.image(template, pictures: pictures)
                    withAnimation(.easeOut(duration: 0.15)) { image = img }
                }
                .overlay(alignment: .topLeading) {
                    Image(systemName: template.mode == .carousel ? "rectangle.split.3x1" : "square.grid.2x2")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(6)
                }
                HStack(spacing: 4) {
                    if template.category == .video {
                        Image(systemName: "play.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.brand)
                    }
                    Text(template.name)
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(template.mode == .carousel ? String(localized: "Carousel") : String(localized: "\(template.slots) photos or videos · \(template.format.short)"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel((template.mode == .carousel ? String(localized: "\(template.name) carousel template") : String(localized: "\(template.name) template, \(template.slots) photos")))
    }
    private func artwork(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            .padding(10)
            .accessibilityHidden(true)
    }

}

/// Category chips: All plus one per category that has templates for the current kind.
struct TemplateCategoryChips: View {
    let mode: EditMode?
    @Binding var category: TemplateCategory?

    var body: some View {
        let available = TemplateCategory.allCases.filter { !templates(for: mode, category: $0).isEmpty }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(String(localized: "All"), on: category == nil) { category = nil }
                ForEach(available) { c in
                    chip(c.title, on: category == c) { category = c }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { action() }
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(on ? Color.white : Color.white.opacity(0.75))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .glassEffect(on ? .regular.tint(Color.brand.opacity(0.75)).interactive() : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

/// Grid of templates, two (iPhone) or more (iPad) per row.
struct TemplateGrid: View {
    let list: [DesignTemplate]
    var pictures: [MediaItem] = []
    let pick: (DesignTemplate) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14)], spacing: 18) {
            ForEach(list) { t in
                TemplateCard(template: t, pictures: pictures) { pick(t) }
            }
        }
        .padding(.horizontal, 16)
    }
}

/// From the editor (Layout / Slides → Templates): templates of this kind, previewed with the person's own pictures.
struct TemplateBrowserSheet: View {
    @Environment(CollageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var category: TemplateCategory?

    var body: some View {
        let mode = store.project.mode
        let list = templates(for: mode, category: category)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "Your photos and videos go into the template in order. Everything stays editable, and Undo brings your design back."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    TemplateCategoryChips(mode: mode, category: $category)
                    TemplateGrid(list: list, pictures: store.items) { t in
                        withAnimation(.smooth) { store.applyTemplate(t) }
                        dismiss()
                        // the template's words are placeholders: select the first, so changing it is one tap away
                        if let first = store.project.captions.first {
                            store.selectCaption(first.id)
                            store.notify(String(localized: "\(t.name) applied. Tap Edit to write your own words; Undo brings your design back."))
                        } else {
                            store.notify(String(localized: "\(t.name) applied. Undo brings your design back."))
                        }
                    }
                }
                .padding(.vertical, 10)
            }
            .navigationTitle(mode == .carousel ? String(localized: "Carousel templates") : String(localized: "Collage templates"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Close"), systemImage: "xmark") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}
