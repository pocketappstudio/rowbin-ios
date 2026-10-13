# Rowbin for iPhone

Native SwiftUI version of Rowbin, the cozy row counter for knitting & crochet. It's a separate app from the Rowbin web app and matches all of its features (see `/workspace/rowbin-native-spec.md`). It also adds Taptic haptics, WidgetKit widgets and App Store billing.

- **Targets:** `Rowbin` (app, iOS 17+), `RowbinWidgets` (WidgetKit extension), `RowbinTests` (unit tests).
- **Shared code (`Shared/`):** data model (JSON matches the web backups), counting engine, App Group store, themes and widget App Intents.
- **Pro:** StoreKit 2 non-consumable `com.pattersonslade.rowbin.pro`, with Restore Purchases (`AppStore.sync()`). `Rowbin.storekit` is for local testing; the price there is a placeholder and isn't final.
- **Widgets:**
  - Small: row count.
  - Medium: row count, interactive −1/+1 and repeat progress.
  - Large: rows and the first extra counter, each with −1/+1.
  - Lock Screen: circular, rectangular and inline row count.
  - Widget data is shared through the App Group `group.com.pattersonslade.rowbin`.
- **Build:** `brew install xcodegen && xcodegen generate`, then open `Rowbin.xcodeproj`. CI (`.github/workflows/ios.yml`) builds an unsigned simulator app and runs the tests on every push.
- **Support:** through the App Store listing only.

CI workflow is staged at `ci/ios.yml`. It goes to `.github/workflows/ios.yml` once the token has the Workflows (write) permission.
