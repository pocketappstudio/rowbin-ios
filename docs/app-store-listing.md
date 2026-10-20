# Rowbin 1.0: App Store listing (en-US), for Slade's approval

Status: entered in App Store Connect (app 6824725835, version 1.0, PREPARE_FOR_SUBMISSION). **Not submitted for review.**

| Field | Value |
|---|---|
| Name (28/30) | Rowbin: Row Counter for Yarn |
| Subtitle (26/30) | Knit & crochet row counter |
| Keywords (94/100) | knitting,crochet,row counter,stitch,yarn,knit,counter,tally,repeat,pattern,chart,amigurumi,pdf |
| Support URL | https://pocketappstudio.github.io/rowbin/ios-support.html |
| Marketing URL | (left empty; see notes) |
| Privacy policy URL | https://pocketappstudio.github.io/rowbin/ios-privacy.html |
| Copyright | 2026 pocketappstudio |
| Primary / secondary category | Lifestyle / Productivity |
| Age rating | All questionnaire items None/No (expected 4+) |
| Price | Free, with in-app purchase |
| Availability | All 175 territories, plus new territories |
| Build | 3 (export compliance: no non-exempt encryption, `ITSAppUsesNonExemptEncryption = false`) |

## Promotional text (146/170)
A calm, ad-free row counter for knitting and crochet. Tap the big +, count by voice, or use a widget. Pro is a one-time purchase, no subscription.

## Description (1882/4000)
```
Rowbin is a simple row counter for knitting and crochet. No ads, no account and no sign-up. It works offline, and every tap saves right away.

COUNT WITHOUT THINKING
• A big + button, with − and Undo
• Reset (with confirmation) and a full History log; tap ↺ to jump back to any earlier count
• Repeat counters for patterns like “8-row repeat × 39”: they roll over and count the repeats you’ve finished
• Lock the counter so pocket taps can’t change it, and keep the screen on while you work
• Gentle haptics on every count
• Works with a keyboard or Bluetooth page turner

FREE
• 2 projects, each with notes and a photo
• 1 extra or repeat counter per project
• Home Screen and Lock Screen widgets, with +1 and −1 buttons on the larger widgets
• Backup export and import, so you can keep a copy or move to a new phone

ROWBIN PRO: ONE-TIME PURCHASE, NO SUBSCRIPTION
• Unlimited projects and unlimited extra counters
• Pattern viewer for PDFs and photos, with a movable line highlighter that can move down with each row
• Chart markup: draw on your pattern with a pen, highlighter or eraser, in 4 colours. Undo, clear, show or hide your marks. Your pattern file itself isn’t changed.
• Voice counting: say “next”, “back”, “undo” or “stop” to count hands-free. It uses your device’s on-device speech recognition only and isn’t available on devices without it. Nothing is recorded or saved.
• Project timer that keeps running when the app is closed
• Themes, including a dark mode and two softer, lower-contrast Calm themes
• Reduce motion setting (Rowbin also follows iOS Reduce Motion for everyone)

PRIVATE BY DESIGN
Your projects, counts, notes, photos and patterns stay on your device. Rowbin has no ads, no analytics and no trackers, and it collects no data. Purchases are handled by Apple.

Made by pocketappstudio. Terms: https://pocketappstudio.github.io/rowbin/ios-terms.html
```

## In-app purchase: com.pocketappstudio.rowbin.pro
- Type: non-consumable. Price: US$14.99 (set earlier). Availability: all territories.
- Display name: Rowbin Pro
- Description (53/55): Unlimited projects, pattern tools and voice counting.
- Review note: One-time, non-consumable unlock for Rowbin Pro: unlimited projects and counters, pattern viewer with line highlighter, chart markup, on-device voice counting, project timer, themes and reduce motion. Open it from any PRO item or Settings > See what Pro adds. Restore Purchases is in Settings.

## App Review notes
```
Rowbin is a row counter for knitting and crochet. No account or login is needed; everything is stored on the device.

Rowbin Pro (non-consumable IAP com.pocketappstudio.rowbin.pro) is a one-time purchase, no subscription. To see it: tap any item marked PRO (for example the "Pattern" chip on the counter screen, or Settings > Theme), or Settings > "See what Pro adds". Restore Purchases is in Settings.

Pro features to try after purchase:
- Pattern viewer: tap "Pattern" on the counter screen and choose any PDF or photo. A movable line highlighter marks the current row.
- Chart markup: in the pattern viewer, tap "Markup", then draw with Pen/Highlighter/Eraser. Tap Done to scroll again.
- Voice counting: tap "Voice" on the counter or pattern screen. Rowbin first explains the feature, then iOS asks for microphone and speech recognition permission. Say "next", "back", "undo" or "stop". Recognition uses SFSpeechRecognizer with requiresOnDeviceRecognition = true and is only offered when supportsOnDeviceRecognition is true; audio never leaves the device and nothing is recorded or read aloud. Listening stops on "stop", when leaving the screen, when the app goes to the background, or after 10 minutes without a command. (The iOS Simulator may not support on-device recognition; a real device is best.)
- Themes (including Calm Linen and Calm Dusk) and Reduce motion: Settings.

Widgets (free): add the Rowbin widget from the Home Screen or Lock Screen widget gallery.
```

## App Privacy
Data Not Collected. The code has no networking of its own: no URLSession, analytics, ads or crash SDKs, and no third-party packages. The only outbound links are the Terms and Privacy pages, which open in Safari. StoreKit is handled by Apple. Voice uses SFSpeechRecognizer with requiresOnDeviceRecognition = true, and no audio or text is stored. Backups are files the user saves themselves.
