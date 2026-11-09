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
        if let l = env["CM_LAYOUT"] { store.setCellCount(Int(l) ?? 4) }
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
        if env["CM_PREVIEW"] == "1" { store.previewOpen = true }
        if env["CM_PLAY"] == "1" { store.playback.play() }
        if let seek = env["CM_SEEK"], let t = Double(seek) { store.playback.seek(to: t) }
    }
}
#endif
