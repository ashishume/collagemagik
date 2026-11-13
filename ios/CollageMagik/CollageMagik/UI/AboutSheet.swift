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

/// "Enjoying CollageMagik? Rate us": opens the App Store review page.
struct RateUsLink: View {
    var body: some View {
        Link(destination: AppLinks.writeReview) {
            HStack(spacing: 8) {
                Text("Enjoying CollageMagik?").foregroundStyle(.secondary)
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill") }
                }
                .font(.caption2)
                .foregroundStyle(.yellow)
                Text("Rate us").fontWeight(.semibold)
            }
            .font(.footnote)
            .padding(.vertical, 6)
        }
        .accessibilityLabel("Enjoying CollageMagik? Rate us on the App Store")
    }
}

/// About, privacy and data: what the app keeps, the legal links, and one button that deletes everything it has stored.
struct AboutSheet: View {
    @Environment(CollageStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var showAdChoices = false
    private let ads = AdManager.shared
    private let gads = GoogleAdsManager.shared

    private var adStatus: String {
        switch ads.choice {
        case .allowed: "Allowed"
        case .declined: "Off"
        case nil: "Not asked yet"
        }
    }

    private var trackingStatus: String {
        switch ads.trackingStatus {
        case .authorized: "Allowed"
        case .denied, .restricted: "Not allowed"
        case .notDetermined: "Not asked yet"
        @unknown default: "Not asked yet"
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
                            Text("CollageMagik").font(.headline)
                            Text("Version \(version)").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Link(destination: AppLinks.writeReview) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rate CollageMagik")
                                Text("A quick rating on the App Store helps a lot. Thank you!").font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                    }
                }

                Section("Your privacy") {
                    Label("No account or sign-in. Your photos, videos and music are processed on this iPhone and never uploaded.", systemImage: "lock.shield")
                    Label("Collages you export are kept in My Library on this iPhone, and only there.", systemImage: "internaldrive")
                    if ads.isEnabled {
                        Label("Ads come from Meta Audience Network. They never get your photos, videos, music or collages.", systemImage: "megaphone")
                    }
                    if gads.isEnabled {
                        Label("Ads come from Google AdMob and keep this app free. They never get your photos, videos, music or collages.", systemImage: "megaphone")
                    }
                }

                if gads.isEnabled {
                    Section {
                        LabeledContent("Tracking (Apple)", value: trackingStatus)
                        if gads.privacyOptionsRequired {
                            Button { gads.presentPrivacyOptions() } label: { Label("Ad privacy choices", systemImage: "slider.horizontal.3") }
                        }
                        if ads.trackingStatus == .denied || ads.trackingStatus == .authorized {
                            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                                Label("Change tracking in Settings", systemImage: "gearshape")
                            }
                        }
                    } header: {
                        Text("Ads")
                    } footer: {
                        Text("A small banner sits above the tool bar, and one full-screen ad appears after you export. Ads never cover your collage while you edit.")
                    }
                }

                if ads.isEnabled {
                    Section {
                        LabeledContent("Show ads", value: adStatus)
                        LabeledContent("Tracking (Apple)", value: trackingStatus)
                        Button { showAdChoices = true } label: { Label("Review ad choices", systemImage: "slider.horizontal.3") }
                        if ads.trackingStatus == .denied || ads.trackingStatus == .authorized {
                            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                                Label("Change tracking in Settings", systemImage: "gearshape")
                            }
                        }
                    } header: {
                        Text("Ads")
                    } footer: {
                        Text("One full-screen ad may appear after you export. It never appears while you edit.")
                    }
                }

                Section("Legal & help") {
                    Link(destination: AppLinks.privacy) { Label("Privacy Policy", systemImage: "hand.raised") }
                    Link(destination: AppLinks.terms) { Label("Terms of Use", systemImage: "doc.text") }
                    Link(destination: AppLinks.support) { Label("Support", systemImage: "lifepreserver") }
                    Link(destination: AppLinks.dataDeletion) { Label("How to delete your data", systemImage: "trash.slash") }
                }

                Section {
                    LabeledContent("My Library") {
                        Text("\(library.entries.count) \(library.entries.count == 1 ? "collage" : "collages") · \(ByteCountFormatter.string(fromByteCount: library.totalBytes, countStyle: .file))")
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete all my data", systemImage: "trash")
                    }
                    .disabled(library.entries.isEmpty && store.items.isEmpty)
                } header: {
                    Text("Data on this iPhone")
                } footer: {
                    Text("Deletes every collage in My Library and clears the collage you are working on. Pictures you saved to the Photos app are yours and are not touched. Deleting the app removes all of this too.")
                }
            }
            .navigationTitle("About & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
            .confirmationDialog("Delete all your data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    withAnimation(.smooth) {
                        store.newCollage()
                        library.removeAll()
                        MediaLoader.purgeTemporaryFiles()
                        ads.resetChoices()
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } message: {
                Text("All collages in My Library and your current collage will be permanently deleted. This can't be undone.")
            }
        }
        .sheet(isPresented: $showAdChoices) { AdNoticeSheet() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
