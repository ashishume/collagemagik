#if DEBUG
import SwiftUI

/// Debug-only: lets a script drive the app headlessly (simulator shares the Mac's filesystem).
/// Env vars: CM_AUTOLOAD=path1,path2  CM_TAB=timeline  CM_PLAY=1  CM_SELECT=0  CM_EXPORT=video|png|ultra  CM_OUT=/path
@MainActor
enum DebugHarness {
    static func run(_ store: CollageStore) async {
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
        if let list = env["CM_BATCH"] {
            await store.addFiles(list.split(separator: ",").map { URL(fileURLWithPath: String($0)) })
            NSLog("CM_DEBUG batch -> cells=%d items=%d tab=%@", store.project.cellCount, store.items.count, store.tab.rawValue)
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
        if let t = env["CM_TAB"] {
            switch t {
            case "timeline": store.tab = .video; store.videoSection = .timeline
            case "audio": store.tab = .video; store.videoSection = .sound
            default: if let tab = Tab(rawValue: t) { store.tab = tab }
            }
        }
        if let st = env["CM_STYLE"] { store.setLayout(st.hasPrefix(carouselLayoutPrefix) ? st : carouselLayoutPrefix + st) }
        NSLog("CM_DEBUG slides=%d photos=%d layout=%@", store.project.slides, store.project.cellCount, store.project.layoutId)
        if let o = env["CM_OFFSET"], let v = Double(o) { store.carouselOffset = v }
        // CM_CAPTIONS=1: one caption per look, to check lettering in the preview and in exports. CM_CAPTION_SELECT=index selects one.
        // CM_CAPTION_TITLE="Summer in Italy" replaces the first caption's text (to match the photos in marketing captures).
        if env["CM_CAPTIONS"] != nil {
            let slides = Double(store.project.slides)
            let samples: [(String, CaptionFont, String, CaptionLook, Double, Double, Double, Double)] = [
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
            store.tab = .text
            if let i = env["CM_CAPTION_SELECT"].flatMap(Int.init), store.project.captions.indices.contains(i) {
                store.selectCaption(store.project.captions[i].id)
            }
            if env["CM_CAPTION_EDIT"] != nil { store.editingCaption = store.selectedCaption }
        }
        if let s = env["CM_SELECT"], let i = Int(s) { store.selectCell(i); store.openPicture() }
        if env["CM_MUSIC"] != nil, let m = env["CM_MUSIC"] { await store.importMusic(URL(fileURLWithPath: m)) }
        if let c = env["CM_CROP"], let i = Int(c) { store.cropCell = i }
        if let e = env["CM_EXPORT"] {
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
                    let url = try await exporter.exportVideo(quality: q) { p in
                        if Int(p * 100) % 25 == 0 { NSLog("CM_DEBUG progress %.2f", p) }
                    }
                    try? FileManager.default.removeItem(atPath: out + ".mp4")
                    try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: out + ".mp4"))
                }
                NSLog("CM_DEBUG export DONE in %.1fs -> %@", Date().timeIntervalSince(start), out)
            } catch {
                NSLog("CM_DEBUG export FAILED: %@", error.localizedDescription)
            }
        }
        if env["CM_DUP"] == "1" { store.duplicateSelectedClip() }
        if env["CM_PART"] == "1" { store.openChoosePart() }
        if env["CM_PREVIEW"] == "1" { store.previewOpen = true }
        if env["CM_PLAY"] == "1" { store.playback.play() }
        if let seek = env["CM_SEEK"], let t = Double(seek) { store.playback.seek(to: t) }
    }
}
#endif
