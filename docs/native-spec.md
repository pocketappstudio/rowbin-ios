# Rowbin native spec (iPhone + Android must match)
Source of truth: the web app `/workspace/rowcounter/app.js` (v1.0, service worker rowbin-v1.3.0) and its README. The web app must NOT be changed.
Rules: no email addresses and no "email me" wording anywhere (support goes through the store listing), no AI wording, premium quality, and nothing gets cut or simplified without asking Slade.

## Data model
JSON keys are identical across web, iPhone and Android, so backups move between all three.
Backup file `rowbin-backup-YYYY-MM-DD.json`: `{ app:"rowbin", schema:1, exportedAt:ISO-8601, state, files:{ "photo:<projectId>"|"pattern:<projectId>": dataURL } }`

**state.settings**
- `theme`: oat | night | sage | berry | ocean
- `haptics` (default true), `tapAnywhere` (false), `locked` (false), `keepAwake` (false)
- `tipsSeen`, `lastBackup` (ms), `lastProjectId`, `createdAt`
- Web-only keys (`license`, `deviceId`, `installDismissed`, `persisted`) are ignored by the native apps. Pro is never imported from a backup.

**project**
- `id`, `name` (max 60, default "My project"), `craft` (knit | crochet)
- `rows` (>=0), `target` (int | null), `notes`, `hasPhoto`
- `pattern`: null, or `{ name, type: pdf | image, page, rel, size (0.012-0.2, default 0.035), zoom (1-3, step 0.25), follow (default true) }`
- `counters[]` (a legacy `reminders[]` key from older data is ignored on load)
- `undo[]`: max 100 snapshots, each `{ rows, c: [[counterId, value, repeats]] }`
- `log[]`: max 500 entries, each `{ t: ms, m: text, r: rows }`
- `timer`: `{ totalMs, runningSince: ms | null, sessions: [[start, end]] }`, max 1000 sessions
- `createdAt`, `updatedAt`

**counter**: `id`, `name` (max 40), `value`, `linked` (default true), `resetAt` (int | null, means "repeat every N"), `repeats`, `repeatTarget` (int | null)


All times are epoch milliseconds. Every change saves immediately. The web app also keeps a last-known-good copy of the state.

## Counting rules
**Main counter**
- +1 / −1 on rows. Rows never go below 0; a −1 at 0 does nothing except a soft haptic.
- Taps are debounced: 220 ms for the main counter, 180 ms for extra counters.
- Every change first saves an undo snapshot (max 100), then logs "Row A → B" (max 500 log entries).
- Linked counters move with each row:
  - +1: value goes up by 1. If resetAt is set and value passes it, value becomes 1 and repeats goes up by 1.
  - −1: if resetAt is set, value is 1 or less and repeats > 0, value becomes resetAt and repeats goes down by 1. Otherwise value = max(0, value − 1).
- Extra counters also have their own +/− with the same rollover rule, are undoable, and log "Name: A → B".

**Undo, reset, history**
- Undo restores rows and every counter's value and repeats, and logs "Undo: row A → B". With nothing to undo, it shows "Nothing to undo".
- Reset needs confirmation. It sets rows to 0, sets linked counters' value and repeats to 0, can be undone, and logs "Reset: row A → 0".
- History shows the newest 60 entries with "Today", "Yesterday" or a date, plus the time. ↺ jumps back to that row ("Restored from history", undoable).
- Editing the current row in the project form logs "Edited: row A → B" (undoable).

**Target and display**
- Target shows "of T · P%" under the count. Reaching the target exactly gives a strong haptic and "🎉 You reached row N!".
- Crochet projects label the count "Row / Round".
- Landscape uses a side-by-side layout.

**Lock and input**
- Lock blocks +/−, undo and extra counters, showing "Counter is locked. Tap 🔒 Locked to unlock."
- Tap-anywhere on the number is off by default.
- Keep screen on applies while the counter is showing.
- Keyboard or Bluetooth page turner: Space, →, ↓ and PageDown add 1. ←, ↑ and PageUp subtract 1. U undoes.

**Screens**
- The app opens straight into the last project. If there are no projects, it creates "My first project" (knit).
- A first-run tips card shows 4 tips and a "Got it" button.
- Projects list, sorted by last updated. Each row shows:
  - craft emoji or photo thumbnail, name and craft
  - "rows of target", day, progress bar and the big count
  - Footer: the free-limit note or "Rowbin Pro ✓", plus a backup nudge ("Last backup: N days ago" / "No backup yet…").
- Project menu:
  - Edit (name, craft, target, current row)
  - New project
  - Reset row count
  - Settings & backup
  - Delete (needs confirmation; also deletes the photo and pattern)

## Free
- Big row counter with undo, reset and full history.
- 2 projects, each with autosaving notes and a photo (downscaled to 1400 px, JPEG quality 0.85).
- 1 extra or repeat counter per project.
- Backup export (photos and patterns optional) and import (confirmation; replaces everything).
- Keep screen on, lock, haptics toggle, tap-anywhere.
- Erase all data (confirmation).
- No ads, no account.
- Native additions, free unless Slade decides otherwise: home-screen and lock-screen widgets, and haptics.

## Pro (one-time, non-consumable)
- Unlimited projects (free: 2) and unlimited extra or repeat counters (free: 1 per project).
- Pattern viewer for PDFs and photos (images downscaled to 2400 px):
  - Zoom 1×–3×.
  - Movable line highlighter, saved as (page, relative Y) so it survives zoom and rotation. It has a drag handle, tap-to-move and ▲/▼ buttons.
  - "Move line with each row" (follow), thinner and thicker settings.
  - Replace or remove the file.
  - +/− buttons and the live count inside the viewer.
- Project timer:
  - Timestamp based, so it keeps running when the app is closed.
  - Start and pause; every session is recorded.
  - Editable total (hours and minutes), shown as H:MM:SS.
- Themes: Oatmeal (default, free), Night Owl (dark), Sage, Berry and Ocean. Without Pro, the app always shows Oatmeal.
- Gating: a "<Feature> is part of Pro" sheet with the feature list, a Buy button and Restore Purchases.

**Store billing replaces the Gumroad license key**
- iOS: StoreKit 2, product id `com.pocketappstudio.rowbin.pro`.
- Android: Google Play Billing. Suggested product id `rowbin_pro`; Play product ids must be lowercase.
- Price: $14.99, one-time purchase, no subscription (decided 2026-10-19).
- A refund or revocation turns Pro off. Projects are never touched.

| Theme | accent | background | card | text | muted |
|---|---|---|---|---|---|
| oat | #B5523B | #FBF6EF | #FFFFFF | #2E2A26 | #6B625A |
| night | #E58A6F | #1B1917 | #26231F | #F3ECE3 | #B9AEA2 |
| sage | #4F7A5A | #F2F5EF | #FFFFFF | #25302A | #5C6B60 |
| berry | #9C3D6B | #FAF3F6 | #FFFFFF | #33232B | #6E5763 |
| ocean | #2F6690 | #F1F5F8 | #FFFFFF | #1F2B33 | #56656F |

Danger color: #A23B2C. Pattern highlighter: yellow at roughly 35% opacity with an amber edge.

## Haptics
Haptics follow the "Vibrate on tap" setting.

| Kind | When | iOS | Android |
|---|---|---|---|
| normal | +1/−1, extra counter, timer | UIImpactFeedbackGenerator(.light) | HapticFeedbackConstants or VibrationEffect predefined effects |
| soft | no-op at 0, undo, lock, pattern tap | .soft impact | same |
| strong | target reached, Pro unlocked | UINotificationFeedbackGenerator(.success) | same |

## Widgets
- Show the last-opened project. Tapping the widget opens that project (`rowbin://project/<id>` on iOS).
- **Small:** project name, row count, target %.
- **Medium:** row count with interactive −1/+1, repeat progress of the first repeat counter (value/N and repeats done/goal).
- **Large:** two counters, each with −1/+1:
  - the main rows, plus target progress
  - the first extra counter, or a prompt to add one if there isn't one
- **Lock screen** (iOS circular, rectangular and inline): row count only. Android phones don't have lock-screen widgets.
- Widget buttons use the same counting rules: undo snapshot, linked counters, log entry, and lock respected.
- Data sharing:
  - iOS: App Group `group.com.pocketappstudio.rowbin`, holding the state JSON with coordinated writes.
  - Android: the app's own storage, refreshed with Glance `updateAll`.

## Apple store asset specs (checked against App Store Connect Help, Oct 13, 2026)
- Screenshots: JPEG or PNG with no alpha, 1 to 10 per display size.
  - Required: iPhone with Dynamic Island (medium display), 1206x2622 or 1179x2556 portrait.
  - If large-display screenshots are provided (1320x2868, 1290x2796 or 1260x2736), Apple scales them down for smaller sizes.
  - iPad 13" (2064x2752) is needed only if the app runs on iPad; the current build is iPhone-only.
- App icon: 1024x1024 PNG (Xcode's single-size icon). The current icon is a placeholder upscaled from the web app's 512 px icon, so a real 1024 master is needed.
- Listing fields:
  - Name: 2–30 characters. Subtitle: up to 30.
  - Promotional text: up to 170. Description: up to 4000, plain text.
  - Keywords: up to 100 bytes; each word longer than 2 characters; no other app or company names.
  - Required URLs: Support URL and Privacy Policy URL. Marketing URL is optional.
  - Also required: Copyright, Category, Age rating, SKU.
  - App Review notes: up to 4000 bytes. App previews: optional, up to 3 per size.
- The "Rowbin Pro" in-app purchase needs its own display name, description and review screenshot in App Store Connect.
- Open conflict: Apple says the Support URL "must lead to actual contact information (legal address, email address, telephone number), as may be required by local law". App Review contact details are private and not shown to users.

## Google Play asset specs (Play Console Help 9866151, Oct 13, 2026)
- App icon: 512x512 32-bit PNG with alpha, up to 1024 KB.
- Feature graphic: 1024x500, JPEG or 24-bit PNG with no alpha.
- Screenshots: at least 2, up to 8 per device type.
  - JPEG or 24-bit PNG with no alpha, 320–3840 px; the long side can't be more than twice the short side.
  - To qualify for recommendations: at least 4 screenshots at 1080x1920 (9:16).
- Short description: up to 80 characters. No emojis, no words like "best", "#1" or "free", no calls to action.
- Title and full-description limits weren't on that page; the Android bot should confirm them.

## Open questions for Slade
1. How to handle Apple's support URL contact rule alongside the no-email rule.
2. A privacy policy page for the native apps, since the web one mentions Gumroad and can't be changed.
3. Should the iPhone app require iOS 17 or later? It's needed for interactive widget buttons.
4. Should widgets be free?
5. Should the large widget's second counter be the first extra counter or a second project?
6. Family Sharing for Pro (currently off).
7. iPhone only, or iPad too?
8. The final price.


## Removed 2026-10-19 (Slade's decision)
Row reminders ("every N rows") and "at the same time" reminders are removed and must not be built. The extra counter's "repeat every N rows" rollover stays.
