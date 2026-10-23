# Draft App Review reply for Rowbin 1.1 (for Slade to approve; NOT sent)

Hello App Review team,

Thank you for the review of Rowbin 1.0 under Guidelines 4.3(a), 4.3(b) and 4.2.6. I'm Slade Patterson, the individual developer. I took your feedback seriously and, before resubmitting, added four new features that change what Rowbin is for. Here are my answers.

1. What the app does and the problem it solves
Rowbin is a knitting and crochet row counter that also does the shaping math, checks gauge and estimates yarn. Knitters often stop mid-project to work out increases, decreases and gauge on paper. Rowbin does that next to the count. New in this version:
- Shaping calculator (Pro): spreads increases or decreases evenly across a row and writes the result out (for example "(K10, M1) × 2, (K9, M1) × 6, K10"). It plans "decrease 2 every 6 rows, 10 times" shaping, or works out the spacing from start and end stitch counts. The plan is a simple list beside the counter with the live stitch count. It never pops up or sends notifications.
- Gauge and yarn planner (Pro): compares the knitter's swatch with the pattern gauge, converts stitch and row counts, estimates yarn from the pattern amount or the swatch weight, and warns inside the screen if the skeins on hand may run short.
- Eyes-free counting (free): a full-screen mode where you tap anywhere to add a row and swipe to subtract or undo. Different haptic patterns mark every 5th row, every 10th row and a finished repeat. It can say the count with the iPhone's built-in speech voice, and it fully supports VoiceOver (adjustable counter, magic tap, Undo action).
- Project journal (free): an automatic timeline of counting sessions built from the row history, with progress photos and notes, simple pace stats, and a finish card drawn on the device that the user can share.
These are in addition to the existing counter, repeat counters, widgets, pattern viewer with row highlighter, chart markup and on-device voice counting.
Everything runs on the device. There is no account, no backend, no ads and no tracking. Pro is a single $14.99 one-time purchase.

2. Intended user
Knitters and crocheters working from patterns, especially garments that need shaping and gauge matching. It is also meant for makers with low vision or who prefer not to look at the screen.

3. The need or gap it fills
Most row counters count rows and repeats. Rowbin keeps the count, the shaping math, gauge conversion and the yarn estimate in one place, plus an eyes-free mode built for touch and VoiceOver.

4. Beta testing
I tested Rowbin myself on my own iPhone through internal TestFlight builds. Issues I found and fixed include a squeezed minus button, the Undo label wrapping onto two lines, and low contrast in the Calm themes. Rowbin was also wrongly set to run on iPad, and three iPad screens didn't lay out correctly, so I made it iPhone-only. I did not use outside testers.

5. Standalone or part of a suite
Rowbin is a standalone product. My other apps are unrelated: Buck Ledger (budgeting), Restock (grocery list), Dialysis Log (fluid tracking) and The WarmUp (a devotional tool for husbands). They share no content, features or audience with Rowbin.

6. Could it be an IAP or feature inside another app?
No. None of my other apps serve knitters or crocheters.

7. Shared code, frameworks or assets with my other apps
Rowbin is native SwiftUI, written for this app. It shares none of the Capacitor code my other apps use. It does share the same distribution certificate and a similar GitHub Actions build-and-upload workflow. I also make a separate Android version of Rowbin itself.

8. Shared codebase, SDK or content library with third-party apps
None. Rowbin uses only Apple frameworks: SwiftUI, WidgetKit, StoreKit 2, PDFKit, Speech and AVFoundation. I designed the app and directed every feature myself, and used AI coding assistants to write much of the code. It is not a purchased template or app-builder service.

9. Made for a client or third party?
No. I came up with the app myself and publish it under my own developer account.

Thank you for taking another look. I'm happy to answer any follow-up questions.

Slade Patterson
