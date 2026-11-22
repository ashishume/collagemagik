import AppTrackingTransparency
import SwiftUI

/// Where the legal pages live. They are on the Axpo Creation site, which is also where the App Store listing points.
enum AppLinks {
    static let privacy = URL(string: "https://www.axpocreation.com/collagemagik/privacy-policy")!
    static let terms = URL(string: "https://www.axpocreation.com/collagemagik/terms-of-service")!
    static let support = URL(string: "https://www.axpocreation.com/collagemagik/support")!
    static let dataDeletion = URL(string: "https://www.axpocreation.com/collagemagik/account-deletion")!
    static let appStore = URL(string: "https://apps.apple.com/app/id6832640005")!
    /// Opens the App Store straight on "Write a Review".
    static let writeReview = URL(string: "https://apps.apple.com/app/id6832640005?action=write-review")!
}

/// "Enjoying Collage Magic? Rate us": opens the App Store review page.
struct RateUsLink: View {
    var body: some View {
        Link(destination: AppLinks.writeReview) {
            HStack(spacing: 8) {
                Text(String(localized: "Enjoying Collage Magic?")).foregroundStyle(.secondary)
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill") }
                }
                .font(.caption2)
                .foregroundStyle(.yellow)
                Text(String(localized: "Rate us")).fontWeight(.semibold)
            }
            .font(.footnote)
            .padding(.vertical, 6)
        }
        .accessibilityLabel(String(localized: "Enjoying Collage Magic? Rate us on the App Store"))
    }
}

/// About, privacy and data: what the app keeps, the legal links, and one button that deletes everything it has stored.
struct AboutSheet: View {
    @Environment(CollageStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    private let gads = GoogleAdsManager.shared

    private var trackingStatus: String {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized: String(localized: "Allowed")
        case .denied, .restricted: String(localized: "Not allowed")
        case .notDetermined: String(localized: "Not asked yet")
        @unknown default: String(localized: "Not asked yet")
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .clipShape(.rect(cornerRadius: 12, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Collage Magic").font(.headline)
                            Text(String(localized: "Version \(version)")).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button { ProStore.shared.openPaywall() } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ProStore.shared.isPro ? String(localized: "Collage Magic Pro is active") : "Collage Magic Pro").foregroundStyle(.primary)
                                Text(ProStore.shared.isPro ? String(localized: "No ads. Thank you for your support!") : String(localized: "Remove all ads: monthly, yearly or once for life."))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: ProStore.shared.isPro ? "checkmark.seal.fill" : "sparkles").foregroundStyle(Color.brand)
                        }
                    }
                    Button { Task { _ = await ProStore.shared.restore() } } label: {
                        Label(String(localized: "Restore purchases"), systemImage: "arrow.clockwise")
                    }
                }

                Section {
                    Link(destination: AppLinks.writeReview) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Rate Collage Magic"))
                                Text(String(localized: "A quick rating on the App Store helps a lot. Thank you!")).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                    }
                }

                Section(String(localized: "Your privacy")) {
                    Label(String(localized: "No account or sign-in. Your photos, videos and music are processed on this iPhone and never uploaded."), systemImage: "lock.shield")
                    Label(String(localized: "Collages you export are kept in My Library on this iPhone, and only there."), systemImage: "internaldrive")
                    if gads.isEnabled {
                        Label(String(localized: "Ads come from Google AdMob and keep this app free. They never get your photos, videos, music or collages."), systemImage: "megaphone")
                    }
                }

                if gads.isEnabled {
                    Section {
                        LabeledContent(String(localized: "Tracking (Apple)"), value: trackingStatus)
                        if gads.privacyOptionsRequired {
                            Button { gads.presentPrivacyOptions() } label: { Label(String(localized: "Ad privacy choices"), systemImage: "slider.horizontal.3") }
                        }
                        if [.denied, .authorized].contains(ATTrackingManager.trackingAuthorizationStatus) {
                            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                                Label(String(localized: "Change tracking in Settings"), systemImage: "gearshape")
                            }
                        }
                    } header: {
                        Text(String(localized: "Ads"))
                    } footer: {
                        Text(String(localized: "A small banner sits above the tool bar, and one full-screen ad appears after you export. Ads never cover your collage while you edit."))
                    }
                }

                Section(String(localized: "Legal & help")) {
                    Link(destination: AppLinks.privacy) { Label(String(localized: "Privacy Policy"), systemImage: "hand.raised") }
                    Link(destination: AppLinks.terms) { Label(String(localized: "Terms of Use"), systemImage: "doc.text") }
                    Link(destination: AppLinks.support) { Label(String(localized: "Support"), systemImage: "lifepreserver") }
                    Link(destination: AppLinks.dataDeletion) { Label(String(localized: "How to delete your data"), systemImage: "trash.slash") }
                }

                Section {
                    LabeledContent(String(localized: "My Library")) {
                        Text(String(localized: "Saved designs: \(library.entries.count) · \(ByteCountFormatter.string(fromByteCount: library.totalBytes, countStyle: .file))"))
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label(String(localized: "Delete all my data"), systemImage: "trash")
                    }
                    .disabled(library.entries.isEmpty && store.items.isEmpty)
                } header: {
                    Text(String(localized: "Data on this iPhone"))
                } footer: {
                    Text(String(localized: "Deletes every collage in My Library and clears the collage you are working on. Pictures you saved to the Photos app are yours and are not touched. Deleting the app removes all of this too."))
                }
            }
            .navigationTitle(String(localized: "About & Privacy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Done"), systemImage: "checkmark") { dismiss() } }
            }
            .confirmationDialog(String(localized: "Delete all your data?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(String(localized: "Delete everything"), role: .destructive) {
                    withAnimation(.smooth) {
                        store.newCollage()
                        library.removeAll()
                        MediaLoader.purgeTemporaryFiles()
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } message: {
                Text(String(localized: "All collages in My Library and your current collage will be permanently deleted. This can't be undone."))
            }
        }
        .proPaywallHost()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
