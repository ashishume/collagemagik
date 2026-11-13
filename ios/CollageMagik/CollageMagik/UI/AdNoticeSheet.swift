import SwiftUI

/// Explains the ads in plain words, once, after the first finished export. In the EU/UK/Switzerland the person must agree;
/// elsewhere "Continue" leads to Apple's tracking prompt, where they choose whether ads may be personalised.
struct AdNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let ads = AdManager.shared

    private var mustAgree: Bool { AdConfig.requiresExplicitConsent }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.brand.gradient, in: .rect(cornerRadius: 18, style: .continuous))
                        .accessibilityHidden(true)

                    Text("Ads keep Insta Collage free")
                        .font(.title2.bold())

                    Text("Insta Collage is free to use, with no account. After you export, we may show one full-screen ad from Meta Audience Network.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        point("photo.on.rectangle.angled", "Your pictures stay yours", "Photos, videos, music and collages are never sent to Meta or to advertisers.")
                        point("hand.raised", mustAgree ? "Ads use your device's advertising ID" : "You choose on the next screen", mustAgree
                              ? "Meta may use it, with data about how you use ads, to choose ads. If you say no, you will see no ads."
                              : "Apple will ask whether apps may track you. If you say \"Ask App Not to Track\", you still see ads, just less personal ones.")
                        point("gearshape", "Change it later", "More ••• → About & Privacy → Ads.")
                    }

                    Link(destination: AppLinks.privacy) {
                        Label("Read the Privacy Policy", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        ads.noticeAnswered(.allowed)
                        dismiss()
                    } label: {
                        Text(mustAgree ? "Allow ads" : "Continue").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)

                    if mustAgree {
                        Button {
                            ads.noticeAnswered(.declined)
                            dismiss()
                        } label: {
                            Text("No ads").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Swiping the sheet away is not an answer: treat it as "ask me again after the next export".
        .onDisappear { ads.noticeDismissed() }
    }

    private func point(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.brand)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
