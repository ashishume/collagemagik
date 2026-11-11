# CollageMagik: App Store submission pack

Everything App Store Connect asks for, with the answers that match what the app does. Bundle ID `com.axpo.collagemagik`,
version 1.0 (build 1), iPhone only, iOS 26+, free with ads (Meta Audience Network), no account, no in-app purchases.

## 1. URLs (the pages live in `axpo-creations-apps/landing-page`)

Deploy the landing page first, then check each URL loads before you submit.

| App Store Connect field | URL |
|---|---|
| Privacy Policy URL (required) | https://www.axpocreation.com/collagemagik/privacy-policy |
| Support URL (required) | https://www.axpocreation.com/collagemagik/support |
| Marketing URL | https://www.axpocreation.com/collagemagik |
| Terms of Use | https://www.axpocreation.com/collagemagik/terms-of-service (or leave Apple's standard EULA) |
| Data deletion (not an account, but linked in the app) | https://www.axpocreation.com/collagemagik/account-deletion |

The same links are inside the app (More ••• → About & Privacy). After the app is live, put its App Store link in
`landing-page/src/lib/constants.ts` (`APPS.collagemagik.iosUrl`) and the "Coming soon" badge becomes a download button.

## 2. Listing text

**Name** (30 max): `CollageMagik`
**Subtitle** (30 max): `Photo & video collage maker`
**Category**: Photo & Video (secondary: Graphics & Design)
**Copyright**: `2026 Ashish Debnath`

**Promotional text** (170 max, editable any time):
> Make collages that move, or swipeable carousels whose photos flow from one slide to the next. Trim clips, add your own music, export in high quality. No account.

**Keywords** (100 max, comma separated, no spaces after commas):
`collage,carousel,photo collage,video collage,seamless,panorama,layout,grid,editor,trim,video editor`

**Description** (4000 max):
```
CollageMagik turns your photos and videos into one collage that actually moves.

TWO WAYS TO CREATE
Collage: one picture or video with up to 9 photos and 2 videos.
Carousel: a swipeable post of 2 to 10 slides. Photos run across the edge between slides, half on one slide and half on the next, so people keep swiping to see the rest. Export one image per slide, ready to post in order.

MIX PHOTOS AND VIDEOS
Put up to 9 pictures in a single frame, and up to 2 of them can be videos that play right inside the collage.

35 LAYOUTS, 3 SHAPES
Choose a layout for the number of pictures you picked, then set the gap, corner roundness and background colour. Make it Story (9:16), Post (4:5) or Square.

EDIT LIKE A PRO, WITH YOUR FINGERS
• Drag, pinch and zoom inside any cell
• Crop, rotate, flip and straighten from -45° to +45°
• Press and hold a picture, then drag it onto another to swap
• A timeline for every video: trim the ends, delay the start, split at the playhead, loop or mute

YOUR OWN MUSIC
Add a song from the Files app, trim it, set the volume and fade it out. There is no built-in music, so there are no surprises about rights.

EXPORT IN HIGH QUALITY
Save an H.264 MP4 at 1080 × 1920, or 2160 × 3840 on iPhones that support it, or a PNG still. Share it anywhere or save it to Photos. Videos are re-read from your originals, so they stay sharp. iPhone HDR and portrait clips are supported.

MY LIBRARY
Every collage you export is kept in My Library, on your iPhone, so you can play, share or save it again later.

PRIVATE BY DESIGN
No account or sign-in. Your photos, videos and music are processed on your iPhone and never uploaded.

Requires iOS 26 or later.
```

**What's New (1.0)**: `First release.`

## 3. App Privacy ("nutrition label")

The app shows Meta Audience Network ads, so the answer is **Yes, data is collected** and the app **tracks**. These match the SDK's own
privacy manifest (`FBAudienceNetwork.framework/PrivacyInfo.xcprivacy`, SDK 6.22.1) and the app's `PrivacyInfo.xcprivacy`:

| Data type | Linked to the user | Used for tracking | Purposes |
|---|---|---|---|
| Device ID | Yes | Yes | Third-party advertising |
| Advertising Data | Yes | Yes | Third-party advertising, Analytics |
| Crash Data | No | No | Analytics |
| Other Diagnostic Data | No | No | Analytics |

- Everything else: **not collected** (no photos/videos/audio, no contact info, no location, no identifiers of your own).
- Tracking domains declared in the manifest: `ep1.facebook.com`, `ep6.facebook.com`.
- Privacy Policy URL: see section 1 (it describes the ads, the data and the choices).

## 4. Age rating questionnaire

Answer **None / No** to every content question. Under *Capabilities*, answer **Advertising = Yes** (the app shows ads); everything
else No (no web access, no user-generated content, no messaging). The calculated rating stays **4+**.

## 5. Export compliance

Already set in the project: `ITSAppUsesNonExemptEncryption = NO` (the app uses no encryption beyond Apple's). You will not be
asked on each upload.

**Tracking (ATT):** `NSUserTrackingUsageDescription` is set and `AppTrackingTransparency` is requested once, after the first finished export
(see `Ads/AdManager.swift`). In App Store Connect, App Privacy must say the app tracks (section 3).

## 6. App Review information

- **Sign-in required**: leave unchecked (there is no login).
- **Contact**: Ashish Debnath, aaxpocreation@gmail.com, plus a phone number (required by Apple, not shown publicly).
- **Notes**:
```
CollageMagik has no account, login or purchases. Everything runs on the device.
To test a collage: tap "Add" (or the ••• menu → Add from Photos), choose 2-4 photos and/or a short video from the photo library, then tap
the Export button (top right) → Export video or Export picture. The result is saved to My Library (••• → My Library).
To test a carousel: tap "Carousel" at the top, add 4-6 photos, swipe the preview or tap the slide numbers under it, then Export (one image per slide).
"Save to Photos" asks for add-only photo permission. Music is optional: Audio tab → Add background music (needs a video in the collage).
Privacy, Terms, Support and "Delete all my data" are in ••• → About & Privacy.
ADS: the app is free and shows one full-screen Meta Audience Network ad after an export (never while editing, and not after the first export). After your
first finished export and closing the export sheet, an "Ads keep CollageMagik free" notice appears, then Apple's tracking prompt. Choices can be changed in
••• → About & Privacy → Ads. In the EU/UK/Switzerland the notice asks to Allow ads or choose No ads. If no ad is available (no fill), nothing is shown.
```
- The review device needs a few photos/videos in Photos. Apple's reviewers have them; if you test on a simulator, add some with
  `xcrun simctl addmedia booted <files>`.

## 7. Screenshots (the one thing that can't be generated for you)

iPhone-only app, so you need **6.9" iPhone** screenshots (1320 × 2868; 1 to 10 images). Apple scales them down for smaller
iPhones. Use real, good-looking photos (a few people and places), not placeholders. Suggested set:

1. A carousel with a photo crossing the slide edge, slide numbers visible ("Photos that flow across slides")
1b. A second carousel screenshot scrolled to slide 2 so the continued photo shows
1c. A 4-photo grid collage, Layout tab open ("35 layouts")
2. A collage with a video, Timeline tab open ("Trim and sync videos")
3. Crop editor ("Crop, rotate, straighten")
4. Export sheet with the finished video ("Export in 1080p or 4K")
5. My Library grid ("Everything you make, kept on your iPhone")

Capture from a Pro Max simulator (it is 6.9"):
```bash
xcrun simctl io booted screenshot ~/Desktop/shot1.png
```
The debug build can pre-load files for you: `SIMCTL_CHILD_CM_BATCH=/path/a.jpg,/path/b.jpg xcrun simctl launch booted com.axpo.collagemagik`
(see `DebugHarness.swift`; it is compiled out of Release builds).

## 8. Build and upload

1. Open `ios/CollageMagik/CollageMagik.xcodeproj`. Signing: team `83FYPW267R` is already set (automatic signing).
2. Target → General: Version `1.0`, Build `1` (raise Build for every upload).
3. Choose **Any iOS Device (arm64)**, then **Product → Archive**.
4. Organizer → **Distribute App → App Store Connect → Upload**.
5. In App Store Connect create the app (bundle ID `com.axpo.collagemagik`), fill sections 1 to 6, add screenshots, pick the build,
   and **Submit for Review**. Do a TestFlight run on a real iPhone first.

## 9. Before you submit: checklist

- [ ] Landing page deployed; the five URLs in section 1 load (and the sitemap lists them).
- [ ] Tried on a real iPhone: photo + video collage, export MP4 and PNG, Save to Photos, My Library (play, share, delete), About → Delete all my data.
- [ ] Tried a real HEVC / HDR iPhone clip and a 60 s export.
- [ ] Screenshots uploaded (section 7).
- [ ] App name `CollageMagik` is available in App Store Connect (names are first-come).
- [ ] Decision on the iOS 26 minimum (section 10).

## 10. Things to know

- **iOS 26 minimum.** The UI uses Liquid Glass APIs (`glassEffect`, `.glassProminent`), so the deployment target is iOS 26.0.
  That is fine for a new app, but it hides the app from iPhones still on iOS 18 or older. Supporting older versions means
  swapping those APIs for `.ultraThinMaterial` fallbacks behind `#available`.
- **Instagram in the UI.** The app says "Instagram safe-area overlay" and uses "Story" sizes. That is descriptive use, but
  the listing above deliberately avoids the name "Instagram" in the name, subtitle and keywords (Apple rejects other
  companies' trademarks in metadata).
- **No account-deletion requirement.** Guideline 5.1.1(v) applies to apps that let you create an account. This one doesn't;
  the in-app "Delete all my data" and the deletion page cover the spirit of it anyway.
- **The landing site loads Google AdSense** on every page (it is in `landing-page/index.html`), including the CollageMagik
  pages. The policy links to the site's own policy for that. If you want the CollageMagik legal pages free of the site's
  ad script, move them to static HTML under `public/` like the `mindstrike` and `figureout` pages.
- **The web version** (`collagemagik-web`, the PWA) is unchanged and still saves nothing: refresh clears the project. My
  Library exists only in the iPhone app.

## 11. Ads (Meta Audience Network): what is built and what you must do

Built in (see `CollageMagik/Ads/`, `UI/AdNoticeSheet.swift`, the Ads section in `UI/AboutSheet.swift`):

- Meta Audience Network SDK 6.22.1 via Swift Package Manager (`https://github.com/meta/FBAudienceNetwork`), iOS 15+ (this app is iOS 26+).
- One **interstitial** after a finished export, once the export sheet is closed. Not after the 1st export, then every 2nd export, never within
  3 minutes of the previous ad (`AdConfig.showEveryNthExport`, `minimumSecondsBetweenAds`).
- The SDK is **not started** until the person has seen the ads notice (EU/UK/Switzerland: they must tap **Allow ads**; **No ads** keeps it off).
  Then Apple's tracking prompt is shown. Declining tracking still shows (less personal) ads.
- `AdInfo.plist` adds Meta's `SKAdNetworkItems` (`v9wttpbfk9.skadnetwork`, `n38lu8286q.skadnetwork`); the project sets `NSUserTrackingUsageDescription`;
  `PrivacyInfo.xcprivacy` declares tracking, the two tracking domains, the data types in section 3 and the UserDefaults reason.
- "Delete all my data" also resets ad choices.

**You must do (cannot be done from code):**

1. In **Meta Monetization Manager** (business.facebook.com/monetization_manager) add the iOS app (bundle ID `com.axpo.collagemagik`, App Store link once live) and create an
   **Interstitial placement**.
2. Paste its ID into `AdConfig.interstitialPlacementID` (`CollageMagik/Ads/AdConfig.swift`). **While it is empty the app shows no ads, no notice and no tracking prompt.**
3. Test on a real iPhone with a test device (Debug builds register the device for Meta test ads automatically), then archive in Release and upload.
4. In App Store Connect: App Privacy (section 3), age rating *Advertising = Yes* (section 4), and the review notes (section 6).
5. If you ever change ad provider or format, update the policy page (`landing-page/src/pages/collagemagik/`), bump `EFFECTIVE_DATE`, and redo sections 3 and 4.

Known to watch: Meta's header marks `FBInterstitialAd.load()` deprecated in favour of a server-side bid payload. It is what Meta's current docs use for a
client-side integration; if a future SDK removes it, switch to `loadAd(withBidPayload:)`.
