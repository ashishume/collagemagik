import StoreKit
import SwiftUI

/// The CollageMagik Pro page: what Pro does (no ads), the three plans, and one clear button.
/// Shown from the ••• menu, About, the export result, the first-ad note, and on its own once every 7 days.
struct ProPaywall: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private let pro = ProStore.shared

    @State private var selected: ProStore.Plan = .yearly
    @State private var message: String?
    @State private var restoring = false
    @State private var showManage = false
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AuroraBackground().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    if pro.isPro { proActive } else {
                        benefits
                        plans
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                if !pro.isPro { footer }
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .padding(.trailing, 16)
            .padding(.top, 12)
            .accessibilityLabel("Close")
        }
        .task {
            await pro.loadProducts()
            if pro.products[.yearly] == nil, let first = available.first?.plan { selected = first }
        }
        .onAppear { withAnimation(.smooth(duration: 0.6).delay(0.1)) { appeared = true } }
        .onChange(of: pro.isPro) { _, now in
            if now { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .alert("CollageMagik Pro", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.55))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    .clipShape(.rect(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                    .overlay(alignment: .topTrailing) {
                        Text("PRO")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                            .foregroundStyle(.black)
                            .offset(x: 12, y: -8)
                    }
                    .scaleEffect(appeared ? 1 : 0.85)
            }
            .accessibilityHidden(true)

            Text("CollageMagik Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.85, green: 0.8, blue: 1)], startPoint: .top, endPoint: .bottom))
            Text(pro.isPro ? "Thank you for supporting CollageMagik." : "Make collages with no ads, and help a tiny team keep the app going.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    // MARK: Benefits

    private var benefits: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            benefit("rectangle.slash", "No banner ads", "A clean editor")
            benefit("play.slash", "No ads after export", "Results open at once")
            benefit("heart.fill", "Support indie work", "Keeps the app going")
            benefit("checkmark.seal", "All tools stay free", "Nothing else locked")
        }
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.brand.gradient, in: .rect(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    // MARK: Plans

    private struct PlanDisplay: Identifiable {
        let plan: ProStore.Plan
        let title: String
        let price: String
        let period: String
        let detail: String
        let badge: String?
        let cta: String
        var id: String { plan.rawValue }
    }

    private var available: [PlanDisplay] {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_PRO_MOCK"] == "1" { return Self.mock }
        #endif
        return [ProStore.Plan.yearly, .monthly, .lifetime].compactMap(display)
    }

    private func display(_ plan: ProStore.Plan) -> PlanDisplay? {
        guard let p = pro.products[plan] else { return nil }
        let trial = pro.introEligible.contains(plan) ? p.subscription?.introductoryOffer.flatMap(trialText) : nil
        switch plan {
        case .yearly:
            let perMonth = (p.price / 12).formatted(p.priceFormatStyle)
            var badge = "Best value"
            if let m = pro.products[.monthly], m.price > 0 {
                let save = 1 - NSDecimalNumber(decimal: p.price).doubleValue / (NSDecimalNumber(decimal: m.price).doubleValue * 12)
                if save >= 0.05 { badge = "Save \(Int((save * 100).rounded()))%" }
            }
            return PlanDisplay(plan: plan, title: "Yearly", price: p.displayPrice, period: "/ year",
                               detail: [trial, "Just \(perMonth) a month"].compactMap { $0 }.joined(separator: " · "),
                               badge: badge, cta: trial != nil ? "Start free trial" : "Get Pro for a year")
        case .monthly:
            return PlanDisplay(plan: plan, title: "Monthly", price: p.displayPrice, period: "/ month",
                               detail: trial ?? "Cancel anytime", badge: nil, cta: trial != nil ? "Start free trial" : "Get Pro monthly")
        case .lifetime:
            return PlanDisplay(plan: plan, title: "Lifetime", price: p.displayPrice, period: "once",
                               detail: "Pay once, no ads forever", badge: "No subscription", cta: "Get Pro forever")
        }
    }

    private func trialText(_ offer: Product.SubscriptionOffer) -> String? {
        guard offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        let unit: String
        switch offer.period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "day"
        }
        return "\(n)-\(unit) free trial" // "7-day free trial", "1-month free trial"
    }

    @ViewBuilder
    private var plans: some View {
        let list = available
        if list.isEmpty {
            VStack(spacing: 12) {
                if pro.loadingProducts {
                    ProgressView().controlSize(.large)
                    Text("Loading plans…").font(.footnote).foregroundStyle(.secondary)
                } else {
                    Label(pro.loadError ?? "The plans couldn't be loaded.", systemImage: "wifi.exclamationmark")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Try again") { Task { await pro.loadProducts() } }.buttonStyle(.glass)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            VStack(spacing: 10) {
                ForEach(list) { d in planCard(d) }
            }
        }
    }

    private func planCard(_ d: PlanDisplay) -> some View {
        let on = selected == d.plan
        return Button {
            withAnimation(.smooth(duration: 0.25)) { selected = d.plan }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(on ? Color.brand : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(d.title).font(.headline)
                        if let badge = d.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(d.plan == .yearly ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(.white.opacity(0.18)), in: Capsule())
                                .foregroundStyle(d.plan == .yearly ? .black : .white)
                        }
                    }
                    Text(d.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(d.price).font(.headline.monospacedDigit())
                    Text(d.period).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(.rect(cornerRadius: 20))
            .glassEffect(on ? .regular.tint(Color.brand.opacity(0.35)) : .regular, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(on ? Color.brand : .white.opacity(0.08), lineWidth: on ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: Footer

    private var footer: some View {
        let current = available.first { $0.plan == selected }
        return VStack(spacing: 10) {
            Button {
                Task { await buy() }
            } label: {
                HStack {
                    if pro.purchasing != nil { ProgressView().tint(.white) }
                    Text(current?.cta ?? "Continue").font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(current == nil || pro.purchasing != nil)

            Text(selected == .lifetime
                 ? "One payment. No subscription, no renewals."
                 : "Renews automatically until you cancel. Cancel anytime in Settings → Apple ID → Subscriptions, at least 24 hours before it renews.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Button(restoring ? "Restoring…" : "Restore purchases") { Task { await restore() } }
                    .disabled(restoring)
                Link("Terms", destination: AppLinks.terms)
                Link("Privacy", destination: AppLinks.privacy)
            }
            .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            Rectangle().fill(.ultraThinMaterial).mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        }
    }

    // MARK: Already Pro

    private var proActive: some View {
        VStack(spacing: 14) {
            Label("Pro is active", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Color.musicGreen)
            Text(activeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if pro.activePlan != .lifetime {
                Button { showManage = true } label: {
                    Label("Manage subscription", systemImage: "creditcard").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private var activeText: String {
        switch pro.activePlan {
        case .lifetime: return "Lifetime: no ads, forever."
        case .some(let plan):
            let name = plan == .yearly ? "Yearly" : "Monthly"
            guard let date = pro.renewalDate else { return "\(name) plan. No ads anywhere in the app." }
            return "\(name) plan · \(pro.willRenew ? "renews" : "ends") \(date.formatted(date: .abbreviated, time: .omitted))."
        case nil: return "No ads anywhere in the app."
        }
    }

    // MARK: Actions

    private func buy() async {
        switch await pro.purchase(selected) {
        case .purchased:
            message = "Welcome to Pro! Ads are gone. Thank you for supporting CollageMagik 💜"
        case .pending:
            message = "Your purchase is waiting for approval. Pro turns on by itself once it's approved."
        case .failed(let why):
            message = why
        case .cancelled:
            break
        }
    }

    private func restore() async {
        restoring = true
        let found = await pro.restore()
        restoring = false
        message = found ? "Your Pro purchase is restored. Ads are gone." : "No Pro purchase was found for this Apple ID."
    }

    #if DEBUG
    /// Placeholder plans so the page can be looked at in the Simulator without a StoreKit configuration (CM_PRO_MOCK=1).
    private static let mock: [PlanDisplay] = [
        PlanDisplay(plan: .yearly, title: "Yearly", price: "₹999", period: "/ year", detail: "1-week free trial · Just ₹83.25 a month",
                    badge: "Save 58%", cta: "Start free trial"),
        PlanDisplay(plan: .monthly, title: "Monthly", price: "₹199", period: "/ month", detail: "Cancel anytime", badge: nil, cta: "Get Pro monthly"),
        PlanDisplay(plan: .lifetime, title: "Lifetime", price: "₹2,499", period: "once", detail: "Pay once, no ads forever",
                    badge: "No subscription", cta: "Get Pro forever"),
    ]
    #endif
}

/// Hosts the Pro page on a screen. Only one screen may present it at a time (a sheet can't open over another from below),
/// so each host says whether it is the one on top.
struct ProPaywallHost: ViewModifier {
    let active: Bool
    private let pro = ProStore.shared

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { active && pro.showPaywall }, set: { if !$0 { pro.showPaywall = false } })) {
            ProPaywall()
                .presentationDragIndicator(.visible)
        }
    }
}

extension View {
    func proPaywallHost(active: Bool = true) -> some View { modifier(ProPaywallHost(active: active)) }
}
