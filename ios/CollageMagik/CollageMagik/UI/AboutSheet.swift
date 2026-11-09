import SwiftUI

/// Where the legal pages live. They are on the Axpo Creation site, which is also where the App Store listing points.
enum AppLinks {
    static let privacy = URL(string: "https://www.axpocreation.com/collagemagik/privacy-policy")!
    static let terms = URL(string: "https://www.axpocreation.com/collagemagik/terms-of-service")!
    static let support = URL(string: "https://www.axpocreation.com/collagemagik/support")!
    static let dataDeletion = URL(string: "https://www.axpocreation.com/collagemagik/account-deletion")!
}

/// About, privacy and data: what the app keeps, the legal links, and one button that deletes everything it has stored.
struct AboutSheet: View {
    @Environment(CollageStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

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
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.brand.gradient, in: .rect(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CollageMagik").font(.headline)
                            Text("Version \(version)").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Your privacy") {
                    Label("No account or sign-in. Your photos, videos and music are processed on this iPhone and never uploaded.", systemImage: "lock.shield")
                    Label("Collages you export are kept in My Library on this iPhone, and only there.", systemImage: "internaldrive")
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
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } message: {
                Text("All collages in My Library and your current collage will be permanently deleted. This can't be undone.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
