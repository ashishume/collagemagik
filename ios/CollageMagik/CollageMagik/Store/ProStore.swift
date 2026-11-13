import StoreKit
import SwiftUI

/// CollageMagik Pro: removes all ads. Three ways to get it, all handled by StoreKit 2 on the iPhone (there is no server):
///
/// * Monthly and Yearly: auto-renewable subscriptions in one subscription group (people can switch between them).
/// * Lifetime: a one-time, non-consumable purchase.
///
/// Apple signs every transaction and StoreKit verifies the signature on the device, so `isPro` comes from
/// `Transaction.currentEntitlements`, not from a flag someone could flip. A cached copy is only used to avoid an ad flashing up
/// at launch before StoreKit has answered.
@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    enum Plan: String, CaseIterable, Identifiable {
        case yearly = "com.axpo.collagemagik.pro.yearly"
        case monthly = "com.axpo.collagemagik.pro.monthly"
        case lifetime = "com.axpo.collagemagik.pro.lifetime"
        var id: String { rawValue }
    }

    /// True while the person has an active subscription or bought Lifetime.
    private(set) var isPro: Bool
    /// Which plan gives Pro right now (nil if none).
    private(set) var activePlan: Plan?
    /// When a subscription renews or ends (nil for Lifetime).
    private(set) var renewalDate: Date?
    private(set) var willRenew = true

    private(set) var products: [Plan: Product] = [:]
    private(set) var loadingProducts = false
    private(set) var loadError: String?
    /// Trial / intro offer the person can still use on each subscription.
    private(set) var introEligible: Set<Plan> = []
    private(set) var purchasing: Plan?

    /// Drives the Pro page (`ProPaywall`).
    var showPaywall = false

    private var updatesTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private enum Key {
        static let cachedPro = "pro.cachedIsPro"
        static let lastPromo = "pro.lastPromoShown"
        static let launches = "pro.launchCount"
    }

    /// Show the Pro page on its own at most this often (and never on the very first launch).
    static let promoInterval: TimeInterval = 7 * 24 * 60 * 60

    private init() {
        isPro = defaults.bool(forKey: Key.cachedPro)
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_PRO"] == "1" { isPro = true }
        if ProcessInfo.processInfo.environment["CM_PRO"] == "0" { isPro = false }
        #endif
    }

    // MARK: Start-up

    /// Call once at launch: listens for renewals, refunds and purchases made elsewhere, and checks what the person owns.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard products.isEmpty, !loadingProducts else { return }
        loadingProducts = true
        loadError = nil
        defer { loadingProducts = false }
        do {
            let list = try await Product.products(for: Plan.allCases.map(\.rawValue))
            var map: [Plan: Product] = [:]
            for p in list { if let plan = Plan(rawValue: p.id) { map[plan] = p } }
            products = map
            var eligible: Set<Plan> = []
            for (plan, p) in map {
                if let sub = p.subscription, sub.introductoryOffer != nil, await sub.isEligibleForIntroOffer { eligible.insert(plan) }
            }
            introEligible = eligible
            if map.isEmpty { loadError = "The plans couldn't be loaded. Check your connection and try again." }
        } catch {
            loadError = "The plans couldn't be loaded: \(error.localizedDescription)"
        }
    }

    /// Reads the signed transactions StoreKit has for this Apple ID.
    func refreshEntitlements() async {
        var plan: Plan?
        var renews: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil, let p = Plan(rawValue: t.productID) else { continue }
            if let exp = t.expirationDate, exp < Date() { continue }
            if p == .lifetime { plan = .lifetime; renews = nil; break }
            plan = p
            renews = t.expirationDate
        }
        var renewing = true
        if let plan, plan != .lifetime {
            var product = products[plan]
            if product == nil { product = try? await Product.products(for: [plan.rawValue]).first }
            if let product, let status = try? await product.subscription?.status.first,
               case .verified(let info) = status.renewalInfo {
                renewing = info.willAutoRenew
            }
        }
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_PRO"] != nil { return }
        #endif
        setPro(plan, renews: renews, willRenew: renewing)
    }

    private func setPro(_ plan: Plan?, renews: Date?, willRenew: Bool) {
        let was = isPro
        activePlan = plan
        renewalDate = renews
        self.willRenew = willRenew
        withAnimation(.smooth) { isPro = plan != nil }
        defaults.set(isPro, forKey: Key.cachedPro)
        if isPro && !was { NSLog("CM_PRO active: %@", plan?.rawValue ?? "-") }
    }

    // MARK: Buying

    enum Outcome { case purchased, cancelled, pending, failed(String) }

    func purchase(_ plan: Plan) async -> Outcome {
        guard let product = products[plan] else { return .failed("This plan isn't available right now.") }
        purchasing = plan
        defer { purchasing = nil }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let t) = verification else { return .failed("The App Store couldn't confirm this purchase.") }
                await t.finish()
                await refreshEntitlements()
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                // e.g. Ask to Buy: Pro turns on by itself once it's approved (Transaction.updates).
                return .pending
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// "Restore purchases": asks the App Store for this Apple ID's purchases again.
    func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return isPro
    }

    // MARK: The weekly Pro page

    /// Call at launch. Shows the Pro page once every 7 days to people without Pro, never on their first launch.
    func appDidLaunch() {
        let launches = defaults.integer(forKey: Key.launches) + 1
        defaults.set(launches, forKey: Key.launches)
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_PAYWALL"] == "1" {
            Task { try? await Task.sleep(for: .seconds(1.5)); showPaywall = true }
            return
        }
        #endif
        guard launches > 1, !isPro else { return }
        let last = defaults.object(forKey: Key.lastPromo) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= Self.promoInterval else { return }
        Task {
            // let the app settle first, and stay out of the way if something else is already on screen
            try? await Task.sleep(for: .seconds(2.5))
            guard !isPro, !showPaywall else { return }
            defaults.set(Date(), forKey: Key.lastPromo)
            showPaywall = true
        }
    }

    /// Opening the Pro page by hand also counts, so the automatic one doesn't follow right after.
    func openPaywall() {
        defaults.set(Date(), forKey: Key.lastPromo)
        showPaywall = true
    }
}
