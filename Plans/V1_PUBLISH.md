# Pineywoods Buck Draw v1.0 — Publishing Plan

**Goal:** Publish Pineywoods Buck Draw as a free iOS app on the App Store and showcase it on pineywoodsweb.com as a portfolio piece for client acquisition.
**Renamed from:** Buck Fever → Pineywoods Buck Draw (2026-05-06) — original name had conflicts with existing Wii game, Android game, and board game.

**Status:** v1 gameplay complete, code pushed to GitHub.

---

## Track 1: App Store (Free Release)

### Prerequisites
- [x] Apple Developer Program membership ($99/year) — confirmed active
- [x] Bundle ID registered: `com.pineywoodsweb.PineywoodsBuckDraw` (2026-05-06)

### App Store Assets Needed
- [x] **App Icon** — 1024x1024 PNG (no alpha, no rounded corners — Apple rounds them)
  - Buck in crosshair reticle, dark green background with pine tree silhouettes
  - Installed in Assets.xcassets/AppIcon.appiconset/ (2026-05-06)
- [x] **Launch Screen** — dark green background with centered app icon
  - Uses Info.plist launch screen keys with LaunchBackground color + LaunchIcon image (2026-05-06)
- [x] **Screenshots** — 6 captured from iPhone 17 Pro simulator (1206x2622)
  - 01_title_screen, 02_gameplay_aiming, 03_arrow_in_flight, 04_arrow_in_flight_2, 05_hit_scoring, 06_game_over
  - Saved in Screenshots/ directory (2026-05-06)
- [ ] **App Preview Video** (optional but high impact)
  - 15-30 second gameplay recording
  - Can record directly from simulator or device

### App Store Connect Setup
- [ ] Create app record in App Store Connect
  - App Name: "Pineywoods Buck Draw"
  - Subtitle: "East Texas Bow Hunting"
  - Primary Category: Games
  - Secondary Category: Entertainment
  - Price: Free
- [ ] Write App Store description
  ```
  Draw your bow. Steady your aim. Welcome to East Texas deer season.

  Pineywoods Buck Draw puts you in the piney woods with a bow, a quiver of arrows,
  and 60 seconds to bag as many bucks as you can. Pull back to draw,
  aim with trajectory dots, and release to let your arrow fly.

  Features:
  - Touch-based bow draw mechanic with haptic feedback
  - Four deer types: spike, 6-point, 8-point, and trophy bucks
  - Hand-crafted deer sprites with organic detail
  - 60-second timed rounds with 15 arrows
  - Score tracking with skill ratings

  Built with love in East Texas.
  ```
- [ ] Keywords: bow hunting, deer, archery, east texas, hunting game, buck, whitetail, pineywoods
- [ ] Privacy Policy URL (required) — can use pineywoodsweb.com/privacy
- [ ] Support URL — pineywoodsweb.com
- [ ] Age Rating: complete the questionnaire (likely 9+ for cartoon violence)

### Build & Submit
- [ ] Set version number to 1.0.0, build number to 1
- [ ] Archive release build in Xcode (Product > Archive)
- [ ] Upload to App Store Connect via Xcode Organizer
- [ ] Submit for App Review
  - Review typically takes 24-48 hours
  - No in-app purchases, no account required, no network calls = smooth review

---

## Track 2: Pineywoodsweb.com Showcase

### Already Done
- [x] Pineywoods Buck Draw portfolio card on /examples page
- [x] Screenshot of main menu
- [x] GitHub link
- [x] Deploy site update (deployed 2026-05-06)

### Still Needed
- [ ] **Gameplay screenshots** — replace/supplement main menu screenshot with in-game action shots
- [ ] **App Store badge** — once live, add "Download on the App Store" badge linking to the listing
- [ ] **Update portfolio card name** — rename from "Buck Fever" to "Pineywoods Buck Draw" on pineywoodsweb.com
- [ ] **Update portfolio card** with:
  - App Store link (once approved)
  - Gameplay screenshot showing deer and arrow in flight
  - Optional: short video/GIF embed

---

## Track 3: Polish Before Submit (Optional but Recommended)

These aren't blockers but would strengthen the submission:

- [x] **App Icon** — designed and added to Assets.xcassets (2026-05-06)
- [x] **Custom Launch Screen** — dark green + centered icon (2026-05-06)
- [ ] **Sound effects** — bow draw, arrow release, deer hit, miss (adds juice)
- [ ] **Accessibility** — VoiceOver labels for HUD elements
- [ ] **iPad support** — verify layout works on iPad (should work with current .resizeFill)

---

## Estimated Timeline

| Task | Effort | Dependency |
|------|--------|------------|
| App icon design | 1 hour | None |
| Launch screen | 30 min | App icon |
| Screenshots (5) | 30 min | Game running |
| App Store Connect setup | 1 hour | Developer account |
| Archive & upload | 30 min | All assets |
| App Review | 1-2 days | Submission |
| Deploy pineywoodsweb | 15 min | None |
| Update portfolio with App Store link | 15 min | App approved |

**Total active work: ~4 hours**
**Calendar time: 2-3 days** (App Review wait)

---

## Decision Log

- **v1 scope:** 60-second timed rounds, 15 arrows, 4 deer types, touch bow mechanic, score ratings. No accounts, no IAP, no network.
- **Free tier only for v1.** Monetization (ads, premium levels) deferred to v2 if there's interest.
- **Bow visual removed** in favor of arrow-only at bottom — cleaner feel per Archon's preference.
- **SKAction trajectory** used instead of SpriteKit physics — more reliable in SpriteView/SwiftUI context.
