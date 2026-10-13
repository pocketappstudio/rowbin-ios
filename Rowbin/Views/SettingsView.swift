import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: ProStore
    @State private var includeFiles = true
    @State private var exportDoc: BackupDocument?
    @State private var showExport = false
    @State private var showImport = false
    @State private var pendingRestore: BackupFile?
    @State private var confirmSpec: ConfirmSpec?

    var body: some View {
        let t = model.theme, st = model.state.settings
        ScrollView {
            VStack(spacing: 14) {
                Card {
                    Text("Counting").font(.headline)
                    Toggle(isOn: setting(\.haptics)) { VStack(alignment: .leading) { Text("Vibrate on tap").bold(); Muted("A gentle tap from the Taptic Engine with each count.") } }
                        .onChange(of: st.haptics) { _, v in if v { model.haptic(.normal) } }
                    Toggle(isOn: setting(\.tapAnywhere)) { VStack(alignment: .leading) { Text("Tap anywhere on the number").bold(); Muted("Off by default so pocket taps and swipes can’t change your count.") } }
                    Toggle(isOn: setting(\.keepAwake)) { VStack(alignment: .leading) { Text("Keep screen on while counting").bold(); Muted("Stops the screen from sleeping on the counter.") } }
                }
                Card {
                    HStack { Text("Theme").font(.headline); ProTag() }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                        ForEach(RowbinTheme.all) { th in
                            let active = Engine.effectiveTheme(st, pro: model.isPro) == th.id
                            Button {
                                if !model.isPro && th.id != "oat" { model.openPro("Themes & dark mode"); return }
                                model.state.settings.theme = th.id; model.save()
                            } label: {
                                HStack { Circle().fill(th.accent).frame(width: 18, height: 18); Text(th.name).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8) }
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(th.background))
                                    .foregroundStyle(th.text)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? t.accent : t.muted.opacity(0.25), lineWidth: active ? 3 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(active ? .isSelected : [])
                        }
                    }
                }
                Card {
                    Text("Backup & transfer").font(.headline)
                    Muted("Your projects are stored only on this iPhone. Save a backup file now and then (to Files, iCloud Drive or another app). To move to a new phone, restore it there. Backups also work with the Rowbin web app and the Android app.")
                    Text("**Last backup:** \(st.lastBackup.map { Date(timeIntervalSince1970: $0 / 1000).formatted(date: .abbreviated, time: .shortened) } ?? "never")").font(.footnote)
                    Toggle("Include photos & pattern files (bigger file)", isOn: $includeFiles).font(.footnote)
                    HStack {
                        Button { exportBackup() } label: { Text("Save backup").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                        Button { showImport = true } label: { Text("Restore…").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                }
                Card {
                    Text("Rowbin Pro").font(.headline)
                    if model.isPro {
                        Text("✓ Pro is unlocked for your Apple Account.")
                        Muted("It works on every iPhone and iPad signed in with the same Apple Account. Use Restore Purchases on a new device.")
                    } else {
                        Text("One-time\(store.priceText.isEmpty ? "" : ", \(store.priceText)"). No subscription.").font(.footnote)
                        Button { model.openPro() } label: { Text("See what Pro adds").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                    Button { Task { await store.restore() } } label: { Text("Restore Purchases").frame(maxWidth: .infinity) }.buttonStyle(.bordered).disabled(store.busy)
                    if let m = store.message { Muted(m) }
                }
                Card {
                    Text("Storage").font(.headline)
                    Muted("Everything is saved on this iPhone as you go. Deleting the app deletes your projects, so keep a backup.")
                    Button(role: .destructive) {
                        confirmSpec = ConfirmSpec(title: "Erase everything?", message: "All projects, counts, notes, photos and patterns on this phone will be deleted. Save a backup first if you might want them back.", ok: "Erase all") { model.eraseAll() }
                    } label: { Text("Erase all data on this phone").frame(maxWidth: .infinity) }.buttonStyle(.bordered).tint(RowbinTheme.danger)
                }
                HStack(spacing: 6) {
                    Button("About, help & privacy") { model.path.append(.about) }
                    Text("· Rowbin \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                }.font(.footnote).foregroundStyle(t.muted)
            }
            .padding(16)
        }
        .background(t.background.ignoresSafeArea())
        .foregroundStyle(t.text)
        .navigationTitle("Settings")
        .fileExporter(isPresented: $showExport, document: exportDoc, contentType: .json, defaultFilename: Backup.fileName()) { result in
            if case .success = result {
                model.state.settings.lastBackup = nowMs(); model.save()
                model.showToast("Backup saved: \(Backup.fileName())", seconds: 3)
            }
        }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let b = try? Backup.parse(data) else { model.showToast("That file isn't a Rowbin backup."); return }
            pendingRestore = b
            let when = Backup.parseISO(b.exportedAt).map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "an unknown date"
            confirmSpec = ConfirmSpec(title: "Restore this backup?", message: "It has \(plural(b.state.projects.count, "project")) from \(when). It will replace everything currently on this phone.", ok: "Restore", destructive: false) { restore() }
        }
        .confirm($confirmSpec)
    }

    func setting(_ kp: WritableKeyPath<Settings, Bool>) -> Binding<Bool> {
        Binding(get: { model.state.settings[keyPath: kp] }, set: { model.state.settings[keyPath: kp] = $0; model.save() })
    }

    func exportBackup() {
        guard let data = Backup.make(state: model.state, includeFiles: includeFiles) else { model.showToast("Backup failed. Try again without photos & patterns."); return }
        exportDoc = BackupDocument(data: data)
        showExport = true
    }

    func restore() {
        guard let b = pendingRestore else { return }
        do {
            var next = try Backup.apply(b, to: model.state)
            let id = Engine.ensureProject(&next)
            model.state = next
            model.save()
            model.path = [.project(id)]
            model.showToast("Backup restored 🧶")
        } catch {
            model.showToast("Restore failed. Your counts were not changed.")
        }
        pendingRestore = nil
    }
}

struct AboutView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let t = model.theme
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Image("AboutIcon").resizable().frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
                    Text("Rowbin").font(.largeTitle.bold())
                    Text("The cozy row counter for knitting & crochet.").bold()
                    Text("No ads. Ever. No account. No subscription. Works offline.").font(.callout)
                }.multilineTextAlignment(.center).padding(.vertical, 8)
                Card {
                    Text("Free forever").font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• The big row counter, with undo, reset and a full history log")
                        Text("• \(Engine.freeProjectLimit) projects with notes and a photo")
                        Text("• \(Engine.freeExtraCounters) extra/repeat counter per project")
                        Text("• Backup export & import")
                        Text("• Keep-screen-on, lock and haptics")
                        Text("• Home Screen and Lock Screen widgets")
                        Text("• No ads, ever. Nothing free will ever move to Pro.")
                    }.font(.callout)
                }
                Card {
                    Text("Pro: one-time purchase").font(.headline)
                    Muted("No subscription.")
                    ProFeatureList()
                    if model.isPro { Text("✓ You have Pro. Thank you!") }
                    else { Button { model.openPro() } label: { Text("Get Pro").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.borderedProminent) }
                }
                Card {
                    Text("Free vs Pro").font(.headline)
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        GridRow { Text(""); Text("Free").bold(); Text("Pro").bold() }
                        ForEach(compareRows.indices, id: \.self) { i in
                            let r = compareRows[i]
                            GridRow { Text(r.0); Text(r.1).gridColumnAlignment(.center); Text(r.2).gridColumnAlignment(.center) }
                            Divider()
                        }
                    }.font(.footnote)
                }
                Card {
                    Text("Quick help").font(.headline)
                    Group {
                        Text("**Repeat counters:** for “repeat rows 1–8, 39 times”, add an extra counter, keep it linked, set “repeat every” to 8 and the repeat goal to 39. Every tap of the main + moves it along. After 8 it goes back to 1 and adds one finished repeat.")
                        Text("**Mis-tap?** Tap Undo, or tap ↺ next to any History entry to jump back to that count.")
                        Text("**Widgets:** touch and hold your Home Screen, tap Edit, then Add Widget and choose Rowbin. The medium and large widgets have +1 and −1 buttons.")
                        Text("**Keyboard or page turner:** Space, → or ↓ adds a row; ← or ↑ subtracts; U undoes.")
                        Text("**Turning the phone sideways** works fine. The counter switches to a side-by-side layout.")
                        Text("**New phone?** Settings → Save backup, then Restore on the new phone, and tap Restore Purchases for Pro.")
                        Text("**Need help?** Use the support link on Rowbin’s App Store page.")
                    }.font(.callout)
                }
                Card {
                    Text("Privacy").font(.headline)
                    Text("Rowbin has no accounts, no ads, no analytics and no trackers. Your projects, notes, photos and patterns are stored only on your device and are never uploaded anywhere. Purchases are handled entirely by Apple through the App Store; Rowbin never sees your payment details. Backups are files you save yourself.").font(.callout)
                }
                Muted("Rowbin \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
            }
            .padding(16)
        }
        .background(t.background.ignoresSafeArea())
        .foregroundStyle(t.text)
        .navigationTitle("About Rowbin")
    }

    var compareRows: [(String, String, String)] {
        [("Big row counter, undo, history", "✓", "✓"), ("Projects", "\(Engine.freeProjectLimit)", "∞"), ("Extra / repeat counters per project", "\(Engine.freeExtraCounters)", "∞"),
         ("Notes & project photo", "✓", "✓"), ("Backup export & import", "✓", "✓"), ("Keep screen on, lock, haptics", "✓", "✓"), ("Widgets", "✓", "✓"),
         ("Row reminders", "–", "✓"), ("Pattern viewer + highlighter", "–", "✓"), ("Project timer", "–", "✓"), ("Themes & dark mode", "–", "✓"), ("Ads", "Never", "Never")]
    }
}
