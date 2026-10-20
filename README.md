# Rowbin for iPhone

Native SwiftUI version of Rowbin, the cozy row counter for knitting & crochet. It's a separate app from the Rowbin web app and matches all of its features (see `/workspace/rowbin-native-spec.md`). It also adds Taptic haptics, WidgetKit widgets and App Store billing.

- **Targets:** `Rowbin` (app, iOS 17+), `RowbinWidgets` (WidgetKit extension), `RowbinTests` (unit tests).
- **Shared code (`Shared/`):** data model (JSON matches the web backups), counting engine, App Group store, themes and widget App Intents.
- **Pro:** StoreKit 2 non-consumable `com.pocketappstudio.rowbin.pro`, with Restore Purchases (`AppStore.sync()`). `Rowbin.storekit` is for local testing; price $14.99, one-time purchase, no subscription.
- **Widgets:**
  - Small: row count.
  - Medium: row count, interactive −1/+1 and repeat progress.
  - Large: rows and the first extra counter, each with −1/+1.
  - Lock Screen: circular, rectangular and inline row count.
  - Widget data is shared through the App Group `group.com.pocketappstudio.rowbin`.
- **Build:** `brew install xcodegen && xcodegen generate`, then open `Rowbin.xcodeproj`. CI (`.github/workflows/ios.yml`) builds an unsigned simulator app and runs the tests on every push.
- **Pro features:** unlimited projects and counters, pattern viewer + highlighter, chart markup, on-device voice counting, timer, themes (incl. Calm), reduce motion.
- **Screenshots:** CI captures DEBUG demo screens (`-rowbinDemo <screen>`) into the `rowbin-ios-simulator` artifact.
- **Support:** the App Store listing or pocketappstudio.gumroad.com. No email or phone in the app.
- **Legal:** About has a Terms card, terms + privacy links (pocketappstudio.github.io/rowbin/ios-terms.html, ios-privacy.html) and "Made by pocketappstudio".

TestFlight: `.github/workflows/ios-testflight.yml` (manual `workflow_dispatch`, macos-26, fastlane `beta` lane; build number = run number; needs secrets ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64, APPLE_TEAM_ID, DIST_CERT_P12_BASE64, DIST_CERT_PASSWORD).
