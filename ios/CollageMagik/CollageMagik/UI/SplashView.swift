import SwiftUI

/// The opening animation: the three tiles of the logo fly in and lock into place, the icon lights up with a burst of
/// sparkles, the name writes itself in, and then the whole thing lifts away to show the editor.
///
/// About 2.4 s in all. With Reduce Motion on it is a short, still fade.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 waiting, 1 tiles in, 2 icon lit, 3 title, 4 shimmer, 5 leaving
    @State private var phase = 0
    @State private var shimmer: CGFloat = -1
    /// 0 → 1 once: the ring around the icon grows and fades. Starts (and ends) invisible at 1.
    @State private var ripple: CGFloat = 1

    private let iconSize: CGFloat = 150
    private let title = Array("Collage Magic")

    var body: some View {
        ZStack {
            AuroraBackground().ignoresSafeArea()

            VStack(spacing: 26) {
                icon
                wordmark
            }
            .offset(y: -20)
        }
        .opacity(phase >= 5 ? 0 : 1)
        .scaleEffect(phase >= 5 ? 1.08 : 1)
        .task { await run() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Collage Magic")
    }

    // MARK: Icon

    private var icon: some View {
        let u = iconSize / 512 // the logo artwork is drawn on a 512 grid
        return ZStack {
            // soft halo that breathes in when the icon lights up
            Circle()
                .fill(RadialGradient(colors: [Color.brand.opacity(0.55), .clear], center: .center, startRadius: 4, endRadius: iconSize))
                .frame(width: iconSize * 2.2, height: iconSize * 2.2)
                .scaleEffect(phase >= 2 ? 1 : 0.4)
                .opacity(phase >= 2 ? 1 : 0)

            // a ring that ripples out once
            RoundedRectangle(cornerRadius: iconSize * 0.24, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 2)
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(1 + ripple * 0.8)
                .opacity(1 - ripple)

            // the coloured backplate of the icon
            RoundedRectangle(cornerRadius: iconSize * 0.24, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.42, blue: 1.0), Color(red: 0.72, green: 0.27, blue: 0.85), Color(red: 1.0, green: 0.5, blue: 0.55)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(phase >= 2 ? 1 : 0.5)
                .opacity(phase >= 2 ? 1 : 0)
                .shadow(color: Color.brand.opacity(0.6), radius: phase >= 2 ? 28 : 0, y: 10)

            // the three tiles, each flying in from its own side
            ZStack {
            tile(width: 157 * u, height: 335 * u, at: CGPoint(x: -89.5 * u, y: 0), from: CGSize(width: -260, height: 120), spin: -28, delay: 0) {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.95), Color(red: 1, green: 0.97, blue: 0.92)], startPoint: .top, endPoint: .bottom)
                    Circle().fill(Color.orange.opacity(0.9)).frame(width: 26 * u * 2).offset(x: 14 * u, y: -230 * u)
                    Ellipse().fill(Color(red: 0.42, green: 0.28, blue: 0.95)).frame(width: 260 * u, height: 150 * u).offset(x: 40 * u, y: 70 * u)
                }
            }
            tile(width: 157 * u, height: 149 * u, at: CGPoint(x: 88.5 * u, y: -93.5 * u), from: CGSize(width: 220, height: -260), spin: 34, delay: 0.08) {
                ZStack {
                    Color.white
                    Image(systemName: "sparkles").font(.system(size: 70 * u, weight: .bold)).foregroundStyle(Color.brand)
                }
            }
            tile(width: 157 * u, height: 164 * u, at: CGPoint(x: 88.5 * u, y: 85 * u), from: CGSize(width: 240, height: 260), spin: -22, delay: 0.16) {
                ZStack {
                    Color.white
                    Image(systemName: "play.fill").font(.system(size: 64 * u, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Color.brand, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            }
            .opacity(phase >= 2 ? 0 : 1)

            // the real artwork takes over once everything has landed
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.24, style: .continuous))
                .opacity(phase >= 2 ? 1 : 0)
                .scaleEffect(phase >= 2 ? 1 : 0.92)

            sparkleBurst
        }
        .frame(width: iconSize, height: iconSize)
        .scaleEffect(phase >= 3 ? 1 : (phase >= 2 ? 1.06 : 1))
    }

    private func tile<Content: View>(
        width: CGFloat, height: CGFloat, at: CGPoint, from: CGSize, spin: Double, delay: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let landed = phase >= 1
        return content()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 30 * iconSize / 512, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .rotationEffect(.degrees(landed ? 0 : spin))
            .scaleEffect(landed ? 1 : 0.4)
            .offset(x: at.x + (landed ? 0 : from.width), y: at.y + (landed ? 0 : from.height))
            .opacity(landed ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.68).delay(delay), value: landed)
    }

    /// Little stars that shoot out of the icon when it lights up.
    private var sparkleBurst: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12 * 2 * .pi + 0.2
                let distance = iconSize * (i.isMultiple(of: 2) ? 1.05 : 0.8)
                Image(systemName: i.isMultiple(of: 3) ? "sparkle" : "circle.fill")
                    .font(.system(size: i.isMultiple(of: 3) ? 16 : 6, weight: .bold))
                    .foregroundStyle(i.isMultiple(of: 2) ? Color.white : Color.laneA)
                    .offset(x: phase >= 2 ? cos(angle) * distance : 0, y: phase >= 2 ? sin(angle) * distance : 0)
                    .scaleEffect(phase >= 2 ? 1 : 0.2)
                    .opacity(phase == 2 ? 1 : 0)
                    .animation(.easeOut(duration: 0.7), value: phase)
            }
        }
    }

    // MARK: Wordmark

    private var wordmark: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(title.enumerated()), id: \.offset) { i, ch in
                    Text(String(ch))
                        .opacity(phase >= 3 ? 1 : 0)
                        .offset(y: phase >= 3 ? 0 : 18)
                        .blur(radius: phase >= 3 ? 0 : 6)
                        .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(Double(i) * 0.035), value: phase)
                }
            }
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.88, green: 0.82, blue: 1)], startPoint: .top, endPoint: .bottom))
            .overlay { shimmerOverlay }
            .shadow(color: Color.brand.opacity(0.5), radius: 12)

            Text("Collages, carousels & video")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
                .opacity(phase >= 3 ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: phase)
        }
    }

    /// A band of light that runs across the name once.
    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.35)
                .rotationEffect(.degrees(18))
                .offset(x: shimmer * geo.size.width * 1.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .mask {
            Text(String(title)).font(.system(size: 36, weight: .heavy, design: .rounded))
        }
        .allowsHitTesting(false)
    }

    // MARK: Timeline

    private func run() async {
        if reduceMotion {
            phase = 3
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 0.3)) { phase = 5 }
            try? await Task.sleep(for: .seconds(0.3))
            onFinish()
            return
        }
        try? await Task.sleep(for: .seconds(0.1))
        phase = 1 // tiles (each carries its own spring)
        try? await Task.sleep(for: .seconds(0.7))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { phase = 2 } // icon lights up
        ripple = 0
        try? await Task.sleep(for: .milliseconds(16))
        withAnimation(.easeOut(duration: 0.8)) { ripple = 1 }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { phase = 3 } // name
        try? await Task.sleep(for: .seconds(0.55))
        withAnimation(.easeInOut(duration: 0.75)) { shimmer = 1.2 }
        try? await Task.sleep(for: .seconds(0.75))
        withAnimation(.easeIn(duration: 0.35)) { phase = 5 }
        try? await Task.sleep(for: .seconds(0.35))
        onFinish()
    }
}

#Preview {
    SplashView {}
        .preferredColorScheme(.dark)
}
