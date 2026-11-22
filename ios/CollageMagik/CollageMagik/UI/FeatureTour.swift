import SwiftUI

/// The feature tour: swipeable pages, each with a small looping animation, shown once after the splash (for new and
/// existing users alike, until they finish or skip it) and again from Settings → Feature tour.
enum FeatureTourState {
    /// Bump the version to show a new tour to everyone once more.
    static let seenKey = "cm.tour.seen.v1"

    static var shouldShow: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["CM_TOUR"] == "1" { return true }
        // the debug harness drives the editor on its own; the tour would sit on top of it
        if env.keys.contains(where: { $0.hasPrefix("CM_") && !["CM_PRO", "CM_PAYWALL", "CM_PRO_MOCK"].contains($0) }) { return false }
        #endif
        return !UserDefaults.standard.bool(forKey: seenKey)
    }

    static func markSeen() { UserDefaults.standard.set(true, forKey: seenKey) }
}

private enum TourPage: Int, CaseIterable, Identifiable {
    case welcome, mix, carousel, templates, style, text, export
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: String(localized: "Welcome to Collage Magic")
        case .mix: String(localized: "Videos that play inside")
        case .carousel: String(localized: "Carousels that flow")
        case .templates: String(localized: "Start from a template")
        case .style: String(localized: "Frames, filters, your style")
        case .text: String(localized: "Words and stickers")
        case .export: String(localized: "Ready for Instagram")
        }
    }

    var text: String {
        switch self {
        case .welcome: String(localized: "The collage maker where your videos actually play. Mix clips and photos in one design, add music, post it.")
        case .mix: String(localized: "Drop up to 3 videos next to your photos. They play right inside the collage. Trim them, set their sound, add a song.")
        case .carousel: String(localized: "Pictures cross the edges of your slides, so people keep swiping. Up to 20 photos, slides added for you.")
        case .templates: String(localized: "Dozens of ready-made looks: photo dumps, travel, birthdays, scrapbooks and more. Your photos and clips go straight in.")
        case .style: String(localized: "Instant prints, film strips, washi tape, neon, hearts. Then a filter: warm, film, vintage, noir.")
        case .text: String(localized: "Captions in 20 lettering styles, neon or vertical, plus emoji and shapes. Drag, pinch and twist to place them.")
        case .export: String(localized: "Export a moving collage as an HD or 4K video, or a still. Carousel slides save in posting order.")
        }
    }
}

struct FeatureTour: View {
    let finish: () -> Void
    @State private var page: TourPage = .welcome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AuroraBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page != .export {
                        Button(String(localized: "Skip")) { done() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)

                TabView(selection: $page) {
                    ForEach(TourPage.allCases) { p in
                        pageView(p).tag(p)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                dots.padding(.bottom, 18)

                Button {
                    if page == .export { done() } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page = TourPage(rawValue: page.rawValue + 1) ?? .export }
                    }
                } label: {
                    Text(page == .export ? String(localized: "Start creating") : String(localized: "Next"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.brand)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: 560)
        }
        .sensoryFeedback(.selection, trigger: page)
    }

    private func done() {
        FeatureTourState.markSeen()
        finish()
    }

    private func pageView(_ p: TourPage) -> some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)
            TourArt(page: p, active: page == p, still: reduceMotion)
                .frame(width: 290, height: 290)
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                Text(p.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(p.text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            Spacer(minLength: 0)
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(TourPage.allCases) { p in
                Capsule()
                    .fill(p == page ? Color.brand : .white.opacity(0.3))
                    .frame(width: p == page ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Page \(page.rawValue + 1) of \(TourPage.allCases.count)"))
    }
}

// MARK: - The animations

/// One page's illustration. Each loops while its page is showing; with Reduce Motion it holds still.
private struct TourArt: View {
    let page: TourPage
    let active: Bool
    let still: Bool

    var body: some View {
        switch page {
        case .welcome: WelcomeArt(run: active && !still)
        case .mix: MixArt(run: active && !still)
        case .carousel: CarouselArt(run: active && !still)
        case .templates: TemplatesArt(run: active && !still)
        case .style: StyleArt(run: active && !still)
        case .text: TextArt(run: active && !still)
        case .export: ExportArt(run: active && !still)
        }
    }
}

/// The sample scenes the template previews use, as pictures.
@MainActor private func scene(_ i: Int) -> Image {
    let s = TemplatePreview.samples
    return Image(uiImage: s[i % s.count].thumbnail)
}

/// Counts 0, 1, 2, … every `every` seconds while `run` is on (and stays at `hold` when it isn't).
private struct Ticker<Content: View>: View {
    let run: Bool
    var every: Double = 0.9
    var hold: Int = 0
    @ViewBuilder let content: (Int) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: every, paused: !run)) { ctx in
            content(run ? Int(ctx.date.timeIntervalSinceReferenceDate / every) : hold)
        }
    }
}

private struct WelcomeArt: View {
    let run: Bool
    @State private var float = false

    var body: some View {
        ZStack {
            Circle().fill(Color.brand.opacity(0.45)).frame(width: 210).blur(radius: 50)
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.clear)
                    .overlay(scene(i).resizable().scaledToFill())
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .frame(width: 120, height: 150)
                    .rotationEffect(.degrees(Double(i - 1) * (float ? 16 : 9)))
                    .offset(x: Double(i - 1) * (float ? 74 : 58), y: float ? -6 : 6)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
            }
            Image("Logo")
                .resizable()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.brand.opacity(0.7), radius: 18)
                .scaleEffect(float ? 1.06 : 0.96)
                .offset(y: 70)
        }
        .onAppear { animate() }
        .onChange(of: run) { animate() }
    }

    private func animate() {
        guard run else { return }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { float.toggle() }
    }
}

/// A 2 × 2 collage fills cell by cell; one cell is a video with a play bar running.
private struct MixArt: View {
    let run: Bool

    var body: some View {
        Ticker(run: run, every: 0.55, hold: 6) { t in
            let shown = t % 9
            let cells = [0, 1, 2, 3]
            VStack(spacing: 6) {
                ForEach(0..<2) { r in
                    HStack(spacing: 6) {
                        ForEach(0..<2) { c in
                            let i = cells[r * 2 + c]
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.08))
                                if shown > i {
                                    scene(i + 3).resizable().scaledToFill()
                                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                                    if i == 1 {
                                        VStack {
                                            Spacer()
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 18, weight: .bold))
                                                .padding(10)
                                                .background(.black.opacity(0.4), in: Circle())
                                            Spacer()
                                            Capsule().fill(.white.opacity(0.3)).frame(height: 4)
                                                .overlay(alignment: .leading) {
                                                    Capsule().fill(Color.brand).frame(width: Double(t % 6) * 22, height: 4)
                                                }
                                                .padding(10)
                                        }
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
            .padding(6)
            .frame(width: 240, height: 290)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shown)
        }
    }
}

/// Three slides side by side with pictures crossing the seams; the strip swipes along.
private struct CarouselArt: View {
    let run: Bool

    var body: some View {
        Ticker(run: run, every: 1.4) { t in
            let slide = Double(t % 3)
            let w = 200.0
            VStack(spacing: 18) {
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        scene(0).resizable().scaledToFill().frame(width: w * 1.4, height: 250).clipped()
                        scene(1).resizable().scaledToFill().frame(width: w * 1.6, height: 250).clipped()
                    }
                    // the slide seams the pictures run across
                    ForEach(1..<3) { k in
                        Path { p in p.move(to: CGPoint(x: 1, y: 0)); p.addLine(to: CGPoint(x: 1, y: 250)) }
                            .stroke(.white, style: StrokeStyle(lineWidth: 2.5, dash: [7, 6]))
                            .frame(width: 3, height: 250)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .offset(x: Double(k) * w - 1)
                    }
                }
                .offset(x: -slide * w)
                .frame(width: 290, height: 250, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: slide)
                HStack(spacing: 6) {
                    ForEach(0..<3) { k in
                        Text("\(k + 1)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .frame(width: 22, height: 22)
                            .background(Double(k) == slide ? Color.brand : .white.opacity(0.15), in: Circle())
                    }
                }
            }
        }
    }
}

/// Template cards fan out and the front one changes.
private struct TemplatesArt: View {
    let run: Bool

    var body: some View {
        Ticker(run: run, every: 1.2) { t in
            let front = t % 3
            ZStack {
                ForEach(0..<3) { i in
                    let pos = (i - front + 3) % 3 // 0 = front
                    card(i)
                        .rotationEffect(.degrees(pos == 0 ? 0 : (pos == 1 ? -12 : 12)))
                        .offset(x: pos == 0 ? 0 : (pos == 1 ? -66 : 66), y: pos == 0 ? 0 : 14)
                        .scaleEffect(pos == 0 ? 1 : 0.86)
                        .zIndex(pos == 0 ? 2 : 1)
                }
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.78), value: front)
        }
    }

    @ViewBuilder private func card(_ i: Int) -> some View {
        let names = [String(localized: "Photo dump"), String(localized: "Travel diary"), String(localized: "Birthday")]
        VStack(spacing: 4) {
            HStack(spacing: 3) { scene(i).resizable().scaledToFill(); scene(i + 4).resizable().scaledToFill() }.frame(height: 90).clipped()
            HStack(spacing: 3) { scene(i + 2).resizable().scaledToFill(); scene(i + 6).resizable().scaledToFill() }.frame(height: 90).clipped()
            Text(names[i]).font(.caption.weight(.semibold)).padding(.top, 2)
        }
        .padding(8)
        .frame(width: 160)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(.black)
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

/// One photo cycles through frames, then a filter.
private struct StyleArt: View {
    let run: Bool
    private let names = [String(localized: "Instant"), String(localized: "Circle"), String(localized: "Film"), String(localized: "Noir")]

    var body: some View {
        Ticker(run: run, every: 1.3, hold: 0) { t in
            let k = t % 4
            VStack(spacing: 16) {
                ZStack {
                    switch k {
                    case 0:
                        VStack(spacing: 0) {
                            scene(2).resizable().scaledToFill().frame(width: 190, height: 190).clipped()
                            Color.clear.frame(height: 46)
                        }
                        .padding(12)
                        .background(Color(white: 0.98), in: RoundedRectangle(cornerRadius: 4))
                        .rotationEffect(.degrees(-4))
                    case 1:
                        scene(2).resizable().scaledToFill().frame(width: 210, height: 210).clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 6))
                    case 2:
                        VStack(spacing: 6) {
                            holes
                            scene(2).resizable().scaledToFill().frame(width: 230, height: 160).clipped()
                            holes
                        }
                        .padding(.vertical, 8)
                        .background(Color(white: 0.06))
                    default:
                        scene(2).resizable().scaledToFill().frame(width: 220, height: 220).clipped()
                            .grayscale(1).contrast(1.3)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .frame(height: 250)
                .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .id(k)
                Text(names[k])
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).frame(height: 30)
                    .glassEffect(.regular.tint(Color.brand.opacity(0.7)), in: .capsule)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: k)
        }
    }

    private var holes: some View {
        HStack(spacing: 9) { ForEach(0..<11) { _ in RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.85)).frame(width: 12, height: 8) } }
    }
}

/// A caption types itself out over a photo while stickers pop on.
private struct TextArt: View {
    let run: Bool
    private let words = Array(String(localized: "Summer in Lisbon"))

    var body: some View {
        Ticker(run: run, every: 0.16, hold: 40) { t in
            let n = min(words.count, t % 34)
            ZStack {
                scene(5).resizable().scaledToFill().frame(width: 260, height: 270).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text(String(words.prefix(n)) + (n < words.count && t % 2 == 0 ? "|" : ""))
                    .font(.custom("SnellRoundhand-Bold", size: 34))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 236)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 6)
                    .offset(y: -60)
                Text("🌊").font(.system(size: 44)).scaleEffect(n > 6 ? 1 : 0.01).rotationEffect(.degrees(-12)).offset(x: -80, y: 70)
                Text("☀️").font(.system(size: 50)).scaleEffect(n > 11 ? 1 : 0.01).offset(x: 86, y: 34)
                Text("BEST WEEK")
                    .font(.system(size: 15, weight: .heavy))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(red: 1, green: 0.85, blue: 0.3), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.black)
                    .rotationEffect(.degrees(-6))
                    .scaleEffect(n >= words.count ? 1 : 0.01)
                    .offset(y: 100)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: n)
        }
    }
}

/// A progress ring fills, then a check, then slides numbered in posting order.
private struct ExportArt: View {
    let run: Bool

    var body: some View {
        Ticker(run: run, every: 0.3, hold: 14) { t in
            let p = t % 20
            let progress = min(1, Double(p) / 8)
            VStack(spacing: 22) {
                ZStack {
                    Circle().stroke(.white.opacity(0.15), lineWidth: 12)
                    Circle().trim(from: 0, to: progress)
                        .stroke(Color.brand, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if progress >= 1 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(Color.musicGreen)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(String(localized: "\(Int(progress * 100))%")).font(.title2.weight(.bold).monospacedDigit())
                    }
                }
                .frame(width: 150, height: 150)
                HStack(spacing: 8) {
                    ForEach(0..<3) { k in
                        scene(k).resizable().scaledToFill().frame(width: 70, height: 88).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(alignment: .topLeading) {
                                Text("\(k + 1)").font(.caption2.weight(.bold))
                                    .padding(5).background(Color.brand, in: Circle()).padding(4)
                            }
                            .opacity(p > 9 + k * 2 ? 1 : 0)
                            .offset(y: p > 9 + k * 2 ? 0 : 20)
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: p)
        }
    }
}
