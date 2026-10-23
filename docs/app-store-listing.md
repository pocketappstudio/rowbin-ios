# Rowbin 1.1: App Store listing (en-US), for Slade's approval

Status: **draft for Slade. Not entered in App Store Connect, not uploaded, not submitted.** 1.0 was rejected under 4.3(a)/(b) and 4.2.6; this version adds four original features (shaping calculator, gauge & yarn planner, eyes-free counting, project journal) and the listing now leads with them.

| Field | Value |
|---|---|
| Name (28/30) | Rowbin: Row Counter for Yarn (unchanged) |
| Subtitle (29/30) | Shaping math, gauge & counter |
| Keywords (100/100) | knitting,crochet,stitch counter,increase,decrease,swatch,yardage,sleeve,amigurumi,pattern,accessible |
| Support URL | https://pocketappstudio.github.io/rowbin/ios-support.html |
| Privacy policy URL | https://pocketappstudio.github.io/rowbin/ios-privacy.html |
| Copyright | 2026 pocketappstudio |
| Primary / secondary category | Lifestyle / Productivity |
| Price | Free, with in-app purchase (Pro US$14.99, one-time) |
| Devices | iPhone only |

Keywords drop "row counter", "yarn" and "counter" because the name and subtitle already cover them (Apple indexes those), which frees room for shaping and gauge words.

## Promotional text (143/170)
Shaping math, gauge and yarn planning, and eyes-free counting, beside a calm, ad-free row counter. Pro is a one-time purchase, no subscription.

## Description (2874/4000)
```
Rowbin is a knitting and crochet row counter that also does the shaping math, checks your gauge and estimates your yarn. No ads, no account and no sign-up. Everything stays on your iPhone.

SHAPING MATH, BESIDE YOUR COUNT (PRO)
• Spread increases or decreases evenly across a row: Rowbin writes it out, for example “(K10, M1) × 2, (K9, M1) × 6, K10”
• Plan “decrease 2 every 6 rows, 10 times” shaping, or let Rowbin work out the spacing from your start and end stitch counts
• The plan sits next to the counter as a simple list, with your live stitch count and which shaping rows are done. It never pops up or interrupts you.

GAUGE & YARN PLANNER (PRO)
• Compare your swatch with the pattern’s gauge and see how much wider or narrower your piece would be
• Convert the pattern’s stitch and row counts to your gauge
• Estimate the yarn you need from the pattern’s amount or your swatch’s weight, and get a warning if your skeins may run short

COUNT WITHOUT LOOKING (FREE)
• A full-screen eyes-free mode: tap anywhere to add a row, swipe to subtract or undo
• Different taps you can feel at every 5th row, every 10th row and when a repeat finishes
• Optional spoken count using your iPhone’s built-in voice, and full VoiceOver support with large text

PROJECT JOURNAL (FREE)
• An automatic timeline of your counting sessions, plus progress photos and notes
• Simple pace stats: rows per session, days knitting, and sessions left to your target
• Mark a project finished and make a finish card to keep or share

THE COUNTER
• A big + button, with − and Undo, Reset and a full History log
• Repeat counters for patterns like “8-row repeat × 39”
• Lock, keep-screen-on, gentle haptics, keyboard and Bluetooth page-turner support
• Home Screen and Lock Screen widgets with +1 and −1 buttons

FREE
• 2 projects, each with notes, a photo and a journal
• 1 extra or repeat counter per project
• Eyes-free counting and the project journal
• Widgets, and backup export and import

ROWBIN PRO: ONE-TIME PURCHASE, NO SUBSCRIPTION
• Shaping calculator and gauge & yarn planner
• Unlimited projects and extra counters
• Pattern viewer for PDFs and photos with a movable row highlighter
• Chart markup: pen, highlighter and eraser on your pattern (your file isn’t changed)
• Voice counting: say “next”, “back”, “undo” or “stop”. It uses your device’s on-device speech recognition only and isn’t available on devices without it. Nothing is recorded or saved.
• Project timer that keeps running when the app is closed
• Themes, including a dark mode and two softer Calm themes, and a Reduce motion setting

PRIVATE BY DESIGN
Your projects, counts, notes, photos and patterns stay on your device. Rowbin has no ads, no analytics and no trackers, and it collects no data. Purchases are handled by Apple.

Made by pocketappstudio. Terms: https://pocketappstudio.github.io/rowbin/ios-terms.html
```

## In-app purchase: com.pocketappstudio.rowbin.pro
- Type: non-consumable. Price: US$14.99. Availability: all territories.
- Display name: Rowbin Pro
- Description (50/55): Shaping & gauge tools, patterns, voice, unlimited.
- Review note: One-time, non-consumable unlock for Rowbin Pro: shaping calculator, gauge & yarn planner, unlimited projects and counters, pattern viewer with line highlighter, chart markup, on-device voice counting, project timer, themes and reduce motion. Open it from any PRO item or Settings > See what Pro adds. Restore Purchases is in Settings.

## App Review notes
```
Rowbin is a knitting and crochet row counter with built-in shaping math, a gauge and yarn planner, an eyes-free counting mode and a project journal. No account or login is needed; everything is stored on the device.

Free features to try:
- Eyes-free counting: on the counter screen, tap the "Eyes-free" chip. Tap anywhere to add a row, swipe left to subtract, swipe down to undo. Haptics differ at every 5th row, every 10th row and when a repeat counter rolls over. "Speak count" uses AVSpeechSynthesizer (on-device). With VoiceOver on, the counter is one adjustable element (swipe up/down) and two-finger double-tap adds a row.
- Project journal: tap "Journal". The timeline is built from the row history; add a photo (PhotosPicker, no library permission needed) or a note. "Make card" renders a finish card on the device; Share uses the system share sheet.

Rowbin Pro (non-consumable IAP com.pocketappstudio.rowbin.pro) is a one-time purchase, no subscription. Tap any item marked PRO, or Settings > "See what Pro adds". Restore Purchases is in Settings.

Pro features to try after purchase:
- Shaping calculator: tap "Shaping", enter "Stitches before row 1" (e.g. 84), add a step such as Decrease 2 every 6 rows 10 times, or use "Work it out for me". Save. The plan appears under the counter with the live stitch count. It is a passive list; it never shows alerts or notifications.
- Gauge & yarn: tap "Gauge & yarn". Enter the pattern gauge and your swatch to see conversions and a yarn estimate with a shortfall warning.
- Pattern viewer, chart markup, voice counting (SFSpeechRecognizer with requiresOnDeviceRecognition = true), timer, themes and Reduce motion, as in 1.0.

Widgets (free): add the Rowbin widget from the Home Screen or Lock Screen widget gallery.
```

## App Privacy
Data Not Collected. The code has no networking of its own: no URLSession, analytics, ads or crash SDKs, and no third-party packages. The only outbound links are the Terms and Privacy pages, which open in Safari. StoreKit is handled by Apple. Voice uses SFSpeechRecognizer with requiresOnDeviceRecognition = true, and no audio or text is stored. Backups are files the user saves themselves.

## Screenshots (1.1, captioned, not uploaded)
Order (shots 1-3 show the new features; the Settings shot is dropped):
1. shaping: "Shaping math, done for you" / "Live stitch count beside your rows"
2. gauge: "Match any pattern’s gauge" / "Convert counts and estimate yarn"
3. eyesfree: "Count without looking" / "Tap anywhere. Feel every 5th and 10th row"
4. journal: "Your project’s story" / "Sessions, pace, photos and a finish card"
5. counter: "A calm, ad-free row counter" / "Big buttons, undo and full history"
6. pattern: "Your pattern, right there" / "PDFs and photos with a row highlighter"
7. markup: "Mark up your chart" / "Pen, highlighter and eraser"
8. voice: "Count by voice" / "On-device only. Nothing is recorded"
9. dusk: "Calm, low-contrast themes" / "Including a soft dark mode"
10. pro: "Pro is a one-time purchase" / "No subscription, no account"

Made by `.github/workflows/store-screenshots.yml` (simulator, real app, DEBUG demo data) and `tools/caption_shots.py` (adds the caption band; output keeps the exact simulator pixel size: 6.9" 1320×2868, 6.3" 1206×2622).
