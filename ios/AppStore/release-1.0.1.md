# CollageMagik 1.0.1: App Store Connect checklist

Everything to enter in App Store Connect for version **1.0.1 (build 2)**: the new Pro plans (in-app purchases), the ads, the privacy answers, and the text for the release. Copy the text blocks as they are.

- App: **Insta Collage Maker & Editor** (home-screen and in-app name: **Insta Collage**), Apple ID `6832640005`, bundle ID `com.axpo.collagemagik`
- App Store link: https://apps.apple.com/app/id6832640005
- Privacy Policy: https://www.axpocreation.com/collagemagik/privacy-policy
- Terms of Use: https://www.axpocreation.com/collagemagik/terms-of-service
- Support: https://www.axpocreation.com/collagemagik/support

---

## 1. Version 1.0.1: "What's New in This Version"

```
• Adjustable collages: drag the borders between pictures to make any cell bigger or smaller.
• Choose part: pick exactly which moment of a video plays, with a filmstrip just like trimming a story.
• Duplicate clips and "Use whole video" in the timeline menu.
• Adding many photos and videos now shows a progress bar ("Adding 2 of 5") and can be cancelled.
• New collages start with a 4-photo grid, and carousels start in the Flow style.
• New: Insta Collage Pro removes all ads. Monthly, yearly (with a free week) or once for life.
• Rate us from the ••• menu. Thank you for every review!
```

---

## 2. In-app purchases (Pro: removes all ads)

The app asks the App Store for these **exact product IDs**. If an ID differs by one character, that plan won't show in the app.

### 2a. Subscription group

App Store Connect → your app → **Monetization → Subscriptions** → create a group.

| Field | Value |
|---|---|
| Reference name | `CollageMagik Pro` |
| Group display name (English) | `Insta Collage Pro` |
| Custom app name (optional) | `Insta Collage` |

Put **Yearly at level 1** and **Monthly at level 2** (the order sets which counts as the upgrade when people switch plans).

### 2b. Monthly subscription

| Field | Value |
|---|---|
| Reference name | `Pro Monthly` |
| Product ID | `com.axpo.collagemagik.pro.monthly` |
| Subscription duration | 1 month |
| Price (suggested) | US $2.99 tier (India ₹199). Let Apple fill the other countries. |
| Family Sharing | Off |
| Display name (≤ 30 chars) | `Pro Monthly` |
| Description (≤ 45 chars) | `No ads in Insta Collage, billed monthly` |

### 2c. Yearly subscription

| Field | Value |
|---|---|
| Reference name | `Pro Yearly` |
| Product ID | `com.axpo.collagemagik.pro.yearly` |
| Subscription duration | 1 year |
| Price (suggested) | US $14.99 tier (India ₹999). That is about 58% less than 12 months of Monthly. |
| Family Sharing | Off |
| Display name (≤ 30 chars) | `Pro Yearly` |
| Description (≤ 45 chars) | `No ads in Insta Collage, billed yearly` |
| Introductory offer | **Free trial, 1 week**, all countries, new subscribers only |

The app reads the trial from the App Store: the Pro page says "1-week free trial" and the button changes to "Start free trial" only for people who can still use it. Change or remove the trial here and the app follows without an update.

### 2d. Lifetime (one-time purchase)

App Store Connect → **Monetization → In-App Purchases** → `+` → **Non-Consumable**.

| Field | Value |
|---|---|
| Reference name | `Pro Lifetime` |
| Product ID | `com.axpo.collagemagik.pro.lifetime` |
| Price (suggested) | US $29.99 tier (India ₹2,499) |
| Family Sharing | Off |
| Display name (≤ 30 chars) | `Pro Lifetime` |
| Description (≤ 45 chars) | `No ads in Insta Collage, forever` |

### 2e. Review information (each of the 3 products)

- **Screenshot**: a screenshot of the Pro page, taken on an iPhone (6.3" or 6.9"). Open it from **••• → Remove ads (Pro)**.
- **Review notes** (paste into each product):

```
Insta Collage Pro removes all ads (the banner above the tool bar and the full-screen ad after an export). Nothing else is locked: every layout, edit and export stays free.

To see it: tap ••• (top right) → "Remove ads (Pro)". The Pro page also opens from About & Privacy, under each export result, and on its own at most once every 7 days.

Purchases are verified on the device with StoreKit 2; there is no account or server. "Restore purchases" is on the Pro page and in ••• → About & Privacy.
```

### 2f. Submit them with the build

Products that have never been approved must go to review **together with a new app version**. On the 1.0.1 version page, scroll to **In-App Purchases and Subscriptions**, click **+**, and select all three. Each product's status must be **Ready to Submit** (it needs a price, a display name, a description and the review screenshot).

---

## 3. App description: add at the end

Apple requires the subscription terms and a Terms of Use link in the App Store listing. Add this to the end of the description:

```
Insta Collage is free to use and shows ads. Insta Collage Pro removes all ads:
• Pro Monthly and Pro Yearly are auto-renewing subscriptions. Pro Yearly starts with a 1-week free trial for new subscribers.
• Pro Lifetime is a one-time purchase.

Payment is charged to your Apple ID when you confirm the purchase. Subscriptions renew automatically unless they are cancelled at least 24 hours before the end of the current period. You can manage or cancel them in Settings → your name → Subscriptions. Any unused part of a free trial ends when you buy a subscription.

Terms of Use: https://www.axpocreation.com/collagemagik/terms-of-service
Privacy Policy: https://www.axpocreation.com/collagemagik/privacy-policy
```

Also check under **App Information → License Agreement**: either keep Apple's standard EULA (then the Terms link above is enough), or paste your own terms there.

---

## 4. App Privacy ("App Privacy" page): update for Google AdMob

1.0.1 shows **Google AdMob** ads (Meta Audience Network is in the code but switched off). Answer the questionnaire like this. Your photos, videos, music and collages never leave the iPhone, so none of that is listed.

**Do you or your third-party partners collect data from this app?** Yes.

| Data type | Collected by | Used for | Linked to the user? | Used for tracking? |
|---|---|---|---|---|
| **Identifiers → Device ID** (advertising identifier, only if the person allows tracking) | Google AdMob | Third-Party Advertising | No | **Yes** |
| **Usage Data → Advertising Data** (which ads were seen or tapped) | Google AdMob | Third-Party Advertising, Analytics | No | **Yes** |
| **Usage Data → Product Interaction** | Google AdMob | Third-Party Advertising, Analytics | No | No |
| **Location → Coarse Location** (from the IP address, not GPS) | Google AdMob | Third-Party Advertising | No | **Yes** |
| **Diagnostics → Crash Data, Performance Data** | Google AdMob | Analytics | No | No |
| **Purchases → Purchase History** (Pro) | handled by Apple; the app only reads it on the device | App Functionality | No | No |

Check this against Google's own guide before you submit, since Google updates it: https://developers.google.com/admob/ios/privacy/data-disclosure

The app asks Apple's "Allow tracking?" question once, at first launch (after Google's EU/UK consent form, before any ad loads), so declaring **tracking = Yes** is correct.

**Privacy Policy:** the page at the URL above should now say that:
- ads come from **Google AdMob** (and possibly Meta Audience Network),
- the advertising ID is used only with the person's permission,
- in the EU/UK, Google's consent form asks first,
- **Insta Collage Pro** is bought through Apple, and the developer never sees any payment details.

---

## 5. Google AdMob console (outside App Store Connect)

1. **Apps → CollageMagik → App settings → Link to app store**: link it to App Store ID `6832640005` once 1.0.1 is live. Live ads stay limited until the app is linked.
2. **app-ads.txt**: publish `https://www.axpocreation.com/app-ads.txt` containing the line AdMob shows under **Apps → View all apps → app-ads.txt**. It looks like:
   ```
   google.com, pub-3743383597691737, DIRECT, f08c47fec0942fa0
   ```
   Also make sure the App Store listing's **Marketing URL** or **Support URL** is on `axpocreation.com`, so AdMob can find the file.
3. **Privacy & messaging → European regulations (GDPR)**: create and **publish** a consent message for CollageMagik. Without it, people in the EU/UK see no ads (the app checks this at launch).
4. **Privacy & messaging → IDFA explainer** is optional: the app asks Apple's tracking question itself at first launch.

Ad unit IDs used by the app (release builds; debug builds use Google's test ads):

| What | ID |
|---|---|
| App ID | `ca-app-pub-3743383597691737~8957379689` |
| Banner | `ca-app-pub-3743383597691737/1946228718` |
| Interstitial (after export) | `ca-app-pub-3743383597691737/3067738697` |

---

## 6. "Notes" for App Review (version page → App Review Information)

```
Insta Collage needs no sign-in, so no demo account is needed. Everything runs on the device: photos, videos and music are never uploaded.

TO TEST A COLLAGE: tap "Add" (or ••• → Add from Photos), choose 2-4 photos and/or a short video, then tap the Export button (top right) → Export video or Export picture. In the Layout tab, drag the borders between pictures to resize cells. Exports are kept in My Library (photo-stack button, top left).
TO TEST A CAROUSEL: tap the carousel button at the top, add 4-6 photos, swipe the preview, then Export (one image per slide).
"Save to Photos" asks for add-only photo permission. Music is optional: Video tab → Sound → Add background music (needs a video in the collage).

ADS (Google AdMob): Apple's tracking prompt appears at first launch (in the EU/UK, after Google's consent form). A small banner sits above the bottom tool bar, and one full-screen ad appears after an export finishes, before the result is shown. Before the first full-screen ad the app shows a short "Thank you for using Insta Collage" note, once. Ads are never shown while editing. If no ad is available (no fill), nothing is shown. In the EU/UK, ad choices can be changed in ••• → About & Privacy → Ad privacy choices.

IN-APP PURCHASES: "Insta Collage Pro" (Monthly, Yearly with a 1-week free trial, Lifetime) only removes ads; every feature stays free. Open it from ••• (top right) → "Remove ads (Pro)". Restore purchases is on the Pro page and in ••• → About & Privacy.

Privacy, Terms, Support and "Delete all my data" are in ••• → About & Privacy.
```

---

## 7. Final check before "Submit for Review"

- [ ] Build **1.0.1 (2)** is uploaded and selected on the version page
- [ ] The 3 products are **Ready to Submit** and added to this version (section 2f)
- [ ] The description ends with the subscription terms and Terms of Use link (section 3)
- [ ] App Privacy is updated and published (section 4)
- [ ] The Privacy Policy page mentions AdMob and Pro
- [ ] `app-ads.txt` is live; the AdMob GDPR message is published (section 5)
- [ ] Age rating still fits: the ads are from AdMob, and the app is not made for children
- [ ] Test on TestFlight: the Pro plans load and can be bought in the sandbox, ads disappear after buying, Restore works
