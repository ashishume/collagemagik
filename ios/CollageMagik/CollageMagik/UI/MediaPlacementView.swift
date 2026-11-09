import AVFoundation
import SwiftUI

/// A layer that shows a live AVPlayer.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class Host: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Host {
        let v = Host()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resize
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ v: Host, context: Context) {
        if v.playerLayer.player !== player { v.playerLayer.player = player }
    }
}

/// A photo or video drawn the way the collage and the crop screen both need it: covering `rect`, then zoomed, panned,
/// turned, flipped and straightened. Drawn at (rect-relative) coordinates inside its parent.
struct MediaPlacementView: View {
    let item: MediaItem
    let rect: PxRect
    let view: MediaView
    var player: AVPlayer? = nil

    var body: some View {
        let p = placeMedia(srcW: item.width, srcH: item.height, cell: rect, view: view)
        content
            .frame(width: item.width * p.scale, height: item.height * p.scale)
            .rotationEffect(.degrees(view.rotation))
            .scaleEffect(x: view.flip ? -1 : 1, y: 1)
            .rotationEffect(.radians(p.angleRad))
            .position(x: p.cx, y: p.cy)
    }

    @ViewBuilder private var content: some View {
        if item.kind == .photo, let img = item.preview {
            Image(uiImage: img).resizable()
        } else {
            ZStack {
                Image(uiImage: item.thumbnail).resizable()
                if let player { PlayerLayerView(player: player) }
            }
        }
    }
}
