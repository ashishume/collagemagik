#if DEBUG
import SwiftUI

/// Debug-only: lets a script drive the app headlessly (simulator shares the Mac's filesystem).
/// New: CM_BACKDROP=gradient:3|pattern:1|blur  CM_STICKERS=😍,heart.fill  CM_SPEED=2  CM_FPS=60
/// Env vars: CM_AUTOLOAD=path1,path2  CM_TAB=timeline  CM_PLAY=1  CM_SELECT=0  CM_EXPORT=video|png|ultra  CM_HDR=1  CM_OUT=/path
/// Drafts: CM_OPEN=n opens the n-th draft, CM_NEW=1 starts a new collage after the last draft reopens. CM_SHEET=export|help|about.
@MainActor
enum DebugHarness {
    /// Set once the harness has run: the editor is shown again every time a design is opened from Home, and the test
    /// set-up must not be loaded into the new design.
    @MainActor private static var done = false

    static func run(_ store: CollageStore) async {
        guard !done else { return }
        done = true
        let env = ProcessInfo.processInfo.environment
        if env["CM_MODE"] == "carousel" { store.setMode(.carousel) }
        if let list = env["CM_AUTOLOAD"] {
            let urls = list.split(separator: ",").map { URL(fileURLWithPath: String($0)) }
            // import one by one so each file's result (or error) is logged
            for u in urls {
                let before = store.items.count
                await store.addFiles([u])
                NSLog("CM_DEBUG import %@ -> %@", u.lastPathComponent, store.items.count > before ? "OK" : "REJECTED (toast: \(store.toast?.text ?? "none"))")
            }
        }
        // CM_START_TEMPLATE=id covers the Home flow: choose a template before importing the batch.
        if let id = env["CM_START_TEMPLATE"], let template = allTemplates.first(where: { $0.id == id }) {
            store.applyTemplate(template)
        }
        if let list = env["CM_BATCH"] {
            await store.addFiles(list.split(separator: ",").map { URL(fileURLWithPath: String($0)) })
            NSLog("CM_DEBUG batch -> cells=%d items=%d tab=%@", store.project.cellCount, store.items.count, store.tab.rawValue)
            if env["CM_START_TEMPLATE"] != nil {
                let slots = store.project.cells.prefix(store.project.cellCount).map { cell in
                    cell.mediaId.flatMap { store.item($0) }.map { $0.kind == .video ? "video" : "photo" } ?? "empty"
                }
                NSLog("CM_DEBUG template slots=%@ playing=%@", slots.joined(separator: ","), store.playback.isPlaying ? "yes" : "no")
            }
        }
        // CM_IMPORT=a,b,c: the Files import path with its loader; logs each "N of M" step until it hides.
        if let list = env["CM_IMPORT"] {
            store.startFileImport(list.split(separator: ",").map { URL(fileURLWithPath: String($0)) })
            var last = ""
            while let p = store.importProgress {
                let line = "\(p.title) \(Int(p.fraction * 100))% \(p.detail)"
                if line != last { NSLog("CM_DEBUG loader %@", line); last = line }
                if env["CM_IMPORT_CANCEL_AT"].flatMap(Int.init) == p.current { store.cancelImport() }
                try? await Task.sleep(for: .milliseconds(5))
            }
            NSLog("CM_DEBUG loader hidden; items=%d toast=%@", store.items.count, store.toast?.text ?? "none")
        }
        if let l = env["CM_LAYOUT"]{ store.setCellCount(Int(l) ?? 4) }
        // CM_SIZES=0.7 or 0.7,0.3: moves the first band border, then the first border inside band 0, as if dragged.
        if let list = env["CM_SIZES"], var grid = store.project.resizableGrid {
            let v = list.split(separator: ",").compactMap { Double($0) }
            if let f = v.first, grid.outer.count > 1 { grid = grid.moving(LayoutDivider(band: nil, index: 0), first: f).grid }
            if v.count > 1, grid.inner[0].count > 1 { grid = grid.moving(LayoutDivider(band: 0, index: 0), first: v[1]).grid }
            store.project.cellSizes = grid
        }
        // CM_LAYOUT_ID=2-inset picks a collage layout by id; CM_FRAME=border|instant|torn|shadow, CM_FRAME_COLOR=#f4ecdc.
        if let id = env["CM_LAYOUT_ID"] { store.setLayout(id) }
        // CM_TEMPLATE=c-tossed applies that template to the loaded pictures
        if let id = env["CM_TEMPLATE"], let t = allTemplates.first(where: { $0.id == id }) { store.applyTemplate(t) }
        if let f = env["CM_FRAME"].flatMap(PhotoFrame.init(rawValue:)) { store.project.frame = f }
        // CM_LOOK=vivid etc. puts that filter on every picture; CM_LOOK_CELL=1 on that cell only
        if let f = env["CM_LOOK"].flatMap(PhotoFilter.init(rawValue:)) {
            let only = env["CM_LOOK_CELL"].flatMap(Int.init)
            for i in store.project.cells.indices where only == nil || only == i { store.setCellLook(i) { $0.filter = f } }
        }
        if let c = env["CM_FRAME_COLOR"] { store.project.frameColor = c }
        if let g = env["CM_GAP"].flatMap(Double.init) { store.project.gap = g }
        // CM_DEMO=1: captions using the bundled scripts, a two-size mix and every decoration.
        if env["CM_DEMO"] != nil {
            store.project.captions += [
                Caption(text: "Bodhgaya trip", font: .vows, size: 150, x: 0.5, y: 0.1, rotation: -4, ornament: .swash),
                Caption(text: "woke up to\nthis view\nKashmir, you beauty!", font: .dreamy, size: 130, x: 0.5, y: 0.34, ornament: .divider, mix: .both, accentFont: .diary),
                Caption(text: "Dawki River,\nMeghalaya", font: .signature, size: 120, x: 0.45, y: 0.58, ornament: .heart),
                Caption(text: "golden hour", font: .diary, color: "#ffd84d", look: .outline, size: 80, x: 0.62, y: 0.9, ornament: .sparkles),
            ]
            if let i = env["CM_CAPTION_SELECT"].flatMap(Int.init), store.project.captions.indices.contains(i) {
                store.selectCaption(store.project.captions[i].id)
            }
        }
        // CM_OVERLAYS=1,2 lays tray photos 1 and 2 on top (CM_OVERLAY_FRAME=torn etc., CM_OVERLAY_SELECT=1 keeps the last selected).
        if let list = env["CM_OVERLAYS"] {
            for i in list.split(separator: ",").compactMap({ Int($0) }) where store.items.indices.contains(i) {
                store.addOverlay(store.items[i].id)
            }
            if let f = env["CM_OVERLAY_FRAME"].flatMap(PhotoFrame.init(rawValue:)) {
                for o in store.project.overlays { store.updateOverlay(o.id) { $0.frame = f } }
            }
            if let c = env["CM_OVERLAY_COLOR"] { for o in store.project.overlays { store.updateOverlay(o.id) { $0.frameColor = c } } }
            if let x = env["CM_OVERLAY_CX"].flatMap(Double.init), let o = store.project.overlays.first {
                store.updateOverlay(o.id) { $0.cx = x; $0.cy = 0.45; $0.w = 0.6 }
            }
            if env["CM_OVERLAY_SELECT"] == nil { store.selectOverlay(nil) }
        }
        if let t = env["CM_TAB"] {
            switch t {
            case "timeline": store.tab = .video; store.videoSection = .timeline
            case "audio": store.tab = .video; store.videoSection = .sound
            default: if let tab = Tab(rawValue: t) { store.tab = tab }
            }
        }
        // CM_STYLE_SECTION=size|spacing|background|frame opens that group of the Style tab
        if let sec = env["CM_STYLE_SECTION"].flatMap(StyleSection.init(rawValue:)) { store.styleSection = sec }
        if let st = env["CM_STYLE"] { store.setLayout(st.hasPrefix(carouselLayoutPrefix) ? st : carouselLayoutPrefix + st) }
        NSLog("CM_DEBUG slides=%d photos=%d layout=%@", store.project.slides, store.project.cellCount, store.project.layoutId)
        if let o = env["CM_OFFSET"], let v = Double(o) { store.carouselOffset = v }
        // CM_CAPTIONS=1: one caption per look, to check lettering in the preview and in exports. CM_CAPTION_SELECT=index selects one.
        // CM_CAPTION_TITLE="Summer in Italy" replaces the first caption's text (to match the photos in marketing captures).
        if env["CM_CAPTIONS"] != nil {
            let slides = Double(store.project.slides)
            // CM_CAPTIONS=new: the newer looks and lettering, plus stacked (vertical) letters
            let newer: [(String, CaptionFont, String, CaptionLook, Double, Double, Double, Double)] = [
                ("neon nights", .retro, "#ff4fd8", .neon, 96, 0.5, 0.1, 0),
                ("Sticker", .rounded, "#ff6b4a", .sticker, 92, 0.32, 0.25, -5),
                ("Gradient", .poster, "#8b6cff", .gradient, 120, 0.5, 0.4, 0),
                ("Vogue issue", .magazine, "#ffffff", .plain, 84, 0.5, 0.55, 0),
                ("ENGRAVED", .engraved, "#f4e9d8", .plate, 60, 0.5, 0.67, 0),
                ("forever yours", .romance, "#ffffff", .plain, 90, 0.5, 0.78, 0),
                ("note to self", .note, "#ffd84d", .plain, 64, 0.3, 0.9, -4),
                ("Slab", .slab, "#52d98c", .outline, 80, 0.75, 0.9, 0),
            ]
            let samples: [(String, CaptionFont, String, CaptionLook, Double, Double, Double, Double)] = env["CM_CAPTIONS"] == "new" ? newer : [
                (env["CM_CAPTION_TITLE"] ?? "Summer in Lisbon", .script, "#ffffff", .plain, 110, 0.5, 0.2, 0),
                ("best week ever", .classic, "#ffd84d", .label, 64, 0.5, 0.36, -6),
                ("day 3 · the old town\nand way too much gelato 🍦", .typewriter, "#ffffff", .plate, 50, 0.5, 0.56, 0),
                ("TAKE ME BACK", .poster, "#ff5fa2", .outline, 120, 0.5, 0.78, 0),
                ("dark ink", .hand, "#101016", .plain, 70, 0.5, 0.9, 4),
            ]
            for (i, s) in samples.enumerated() {
                let x = slides > 1 ? 0.5 + Double(i % Int(slides)) : s.5
                store.project.captions.append(Caption(text: s.0, font: s.1, color: s.2, look: s.3, size: s.4, x: x, y: s.6, rotation: s.7))
            }
            if env["CM_CAPTIONS"] == "new" {
                var v = Caption(text: "STACK", font: .poster, color: "#ffffff", look: .label, size: 64, x: 0.9, y: 0.4)
                v.vertical = true
                store.project.captions.append(v)
            }
            store.tab = .text
            if let i = env["CM_CAPTION_SELECT"].flatMap(Int.init), store.project.captions.indices.contains(i) {
                store.selectCaption(store.project.captions[i].id)
            }
            if env["CM_CAPTION_EDIT"] != nil { store.editingCaption = store.selectedCaption }
        }
        // CM_BACKDROP=gradient:3 | pattern:1 | blur
        if let b = env["CM_BACKDROP"] {
            let parts = b.split(separator: ":")
            if let k = BackdropKind(rawValue: String(parts[0])) { store.project.backdrop.kind = k }
            if parts.count > 1, let n = Int(parts[1]) { store.project.backdrop.gradient = n; store.project.backdrop.pattern = n }
        }
        // CM_STICKERS=😍,heart.fill (names with a dot are shapes); CM_STICKER_SELECT=1 keeps the last one selected
        if let list = env["CM_STICKERS"] {
            for item in list.split(separator: ",").map(String.init) {
                store.addSticker(item, kind: item.contains(".") ? .shape : .emoji)
            }
            if env["CM_STICKER_SELECT"] == nil { store.selectSticker(nil) }
        }
        // CM_SPEED=2: every clip at that speed
        if let sp = env["CM_SPEED"].flatMap(Double.init) {
            for li in store.project.lanes.indices {
                store.project.lanes[li].clips = store.project.lanes[li].clips.map { setSpeed($0, sp) }
            }
        }
        // CM_FIT=i fits one cell with blurred sides; blur or a hex colour applies to all cells.
        if let bars = env["CM_FIT"] {
            if let i = Int(bars) {
                store.setCellView(i) { $0.fit = true; $0.fitBars = fitBlur }
            } else {
                for i in store.project.cells.indices { store.setCellView(i) { $0.fit = true; $0.fitBars = bars } }
            }
        }
        if let i = env["CM_ROTATE"].flatMap(Int.init) { store.setCellView(i) { $0.rotation = 90 } }
        if let i = env["CM_FLIP"].flatMap(Int.init) { store.setCellView(i) { $0.flip = true } }
        if let parts = env["CM_ANGLE"]?.split(separator: ":"), parts.count == 2,
           let i = Int(parts[0]), let degrees = Double(parts[1]) {
            store.setCellView(i) { $0.angle = clamp(degrees, -45, 45) }
        }
        if let radius = env["CM_RADIUS"].flatMap(Double.init) { store.project.radius = radius }
        if env["CM_BACKDROP"] == "blur" { store.project.backdrop.blurMediaId = store.items.first { $0.kind == .photo }?.id }
        if let s = env["CM_SELECT"], let i = Int(s) { store.selectCell(i); store.openPicture() }
        // CM_RESIZE=1 opens the selected picture's Resize options
        if env["CM_RESIZE"] != nil { store.resizeOpen = true }
        if env["CM_MUSIC"] != nil, let m = env["CM_MUSIC"] { await store.importMusic(URL(fileURLWithPath: m)) }
        if let c = env["CM_CROP"], let i = Int(c) { store.cropCell = i }
        if let dir = env["CM_TEMPLATE_FRAMES"] { writeTemplateFrames(store, to: dir, only: env["CM_TEMPLATE_IDS"]) }
        if let e = env["CM_EXPORT"] {
            store.playback.pause()
            let snapshot = ExportSnapshot(project: store.project, items: Dictionary(uniqueKeysWithValues: store.items.map { ($0.id, $0) }))
            let exporter = CollageExporter(snapshot: snapshot)
            let out = env["CM_OUT"] ?? "/tmp/cm-export"
            let start = Date()
            do {
                if e == "png" {
                    let url = try exporter.exportPNG(at: Double(env["CM_AT"] ?? "1") ?? 1, quality: .standard)
                    try? FileManager.default.removeItem(atPath: out + ".png")
                    try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: out + ".png"))
                } else {
                    let q: ExportQuality = e == "ultra" ? .ultra : .standard
                    // CM_EXPORT_CANCEL=s taps Cancel s seconds into the export
                    if let s = env["CM_EXPORT_CANCEL"].flatMap(Double.init) {
                        Task {
                            try? await Task.sleep(for: .seconds(s))
                            NSLog("CM_DEBUG export cancel")
                            exporter.cancel()
                        }
                    }
                    let url = try await exporter.exportVideo(quality: q, hdr: env["CM_HDR"] == "1", fps: Int(env["CM_FPS"] ?? "30") ?? 30) { p in
                        if Int(p * 100) % 25 == 0 { NSLog("CM_DEBUG progress %.2f", p) }
                    }
                    try? FileManager.default.removeItem(atPath: out + ".mp4")
                    try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: out + ".mp4"))
                }
                let line = String(format: "CM_DEBUG export DONE in %.1fs -> %@", Date().timeIntervalSince(start), out)
                NSLog("%@", line)
                if let path = env["CM_EXPORT_STATUS"] { try? line.write(toFile: path, atomically: true, encoding: .utf8) }
            } catch {
                let line = "CM_DEBUG export FAILED: \(error)"
                NSLog("%@", line)
                if let path = env["CM_EXPORT_STATUS"] { try? line.write(toFile: path, atomically: true, encoding: .utf8) }
            }
        }
        if env["CM_DUP"] == "1" { store.duplicateSelectedClip() }
        // CM_SHEET=export|help|about opens that sheet (for screenshots)
        switch env["CM_SHEET"] {
        case "export": store.exportOpen = true
        case "help": store.helpOpen = true
        case "about": store.aboutOpen = true
        default: break
        }
        // CM_OPEN=n: opens the n-th draft in My Library (0 = newest), as tapping it there does
        if let n = env["CM_OPEN"].flatMap(Int.init) {
            try? await Task.sleep(for: .seconds(4))
            if store.drafts.indices.contains(n) {
                let id = store.drafts[n].id
                await store.openDraft(id)
                NSLog("CM_DEBUG opened draft %@: items %d, cells %d, current %@", id, store.items.count, store.placedMediaCount, store.draftId)
            }
        }
        // CM_NEW=1: after the last draft has reopened, start a new collage (the draft must stay in My Library)
        if env["CM_NEW"] == "1" {
            try? await Task.sleep(for: .seconds(4))
            NSLog("CM_DEBUG before new: draft %@ items %d", store.draftId, store.items.count)
            store.newCollage()
            try? await Task.sleep(for: .seconds(2))
            NSLog("CM_DEBUG after new: draft %@ items %d drafts %d", store.draftId, store.items.count, store.drafts.count)
        }
        if env["CM_PART"] == "1" { store.openChoosePart() }
        if env["CM_PREVIEW"] == "1" { store.previewOpen = true }
        if env["CM_PLAY"] == "1" { store.playback.play() }
        if let seek = env["CM_SEEK"], let t = Double(seek) { store.playback.seek(to: t) }
        if env["CM_SEEK"] != nil, store.project.isMotion {
            for (i, r) in store.shown.cellRects(W: 1080, H: 1920).enumerated() {
                NSLog("CM_DEBUG motion cell %d x=%.0f y=%.0f w=%.0f h=%.0f alpha=%.2f", i, r.x, r.y, r.w, r.h, store.shown.cellAlpha(i))
            }
        }
    }

    /// CM_TEMPLATE_FRAMES=dir: every motion template (CM_TEMPLATE_IDS=a,b for some) drawn with the loaded photos, or the
    /// sample scenes, as one strip per template (dir/<id>.png): each scene just after it starts and once it has settled.
    private static func writeTemplateFrames(_ store: CollageStore, to dir: String, only: String?) {
        let ids = only.map { Set($0.split(separator: ",").map(String.init)) }
        let photos = store.items.filter { $0.kind == .photo }
        let items = photos.isEmpty ? TemplatePreview.samples : photos
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for template in allTemplates where template.motion != nil && (ids?.contains(template.id) ?? true) {
            let project = template.project(basedOn: Project(), pictures: (0..<template.slots).map { items[$0 % items.count].id })
            guard let motion = project.motion else { continue }
            let times = motion.scenes.indices.flatMap { k in [motion.starts[k] + 0.2, motion.settledTime(of: k)] }
            let h = 400.0, w = (h * project.canvasWidth / project.canvasHeight).rounded(), pad = 8.0
            guard let ctx = CollageRenderer.makeContext(width: Int((w + pad) * Double(times.count)), height: Int(h)) else { continue }
            for (f, t) in times.enumerated() {
                ctx.saveGState()
                ctx.translateBy(x: (w + pad) * Double(f), y: 0)
                ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: h))
                CollageRenderer.draw(ctx: ctx, W: w, H: h, snapshot: ExportSnapshot(project: project, items: byId), t: t) { id in
                    byId[id].flatMap { ($0.fixedPreview ?? $0.thumbnail).cgImage }
                }
                ctx.restoreGState()
            }
            if let cg = ctx.makeImage() {
                try? UIImage(cgImage: cg).pngData()?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(template.id).png"))
            }
        }
        NSLog("CM_DEBUG template frames written to %@", dir)
    }
}
#endif
