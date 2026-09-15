import AppKit
import ServiceManagement
import UserNotifications

let prayerNames = ["Subuh", "Syuruk", "Zohor", "Asar", "Maghrib", "Isyak"]
/// Syuruk (sunrise) marks the end of Subuh, so it's shown in the menu but never notified.
let notifiedPrayers: Set<String> = ["Subuh", "Zohor", "Asar", "Maghrib", "Isyak"]
let reminderMinutes = 10
let singapore = TimeZone(identifier: "Asia/Singapore")!

struct Prayer {
    let name: String
    let time: Date
    var isNotified: Bool { notifiedPrayers.contains(name) }
}

/// Daily times from Resources/timetable.json: "yyyy-MM-dd" → prayer name → "HH:mm" (Singapore time).
final class Timetable {
    private var days: [String: [String: String]] = [:]
    private var calendar = Calendar(identifier: .gregorian)
    private let keyFormatter = DateFormatter()

    init() {
        calendar.timeZone = singapore
        keyFormatter.calendar = calendar
        keyFormatter.timeZone = singapore
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")
        keyFormatter.dateFormat = "yyyy-MM-dd"
        if let url = Bundle.main.url(forResource: "timetable", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            days = (try? JSONDecoder().decode([String: [String: String]].self, from: data)) ?? [:]
        }
    }

    var lastDay: Date? { days.keys.max().flatMap(keyFormatter.date(from:)) }

    func dayKey(_ date: Date) -> String { keyFormatter.string(from: date) }

    func prayers(on date: Date) -> [Prayer] {
        guard let times = days[dayKey(date)] else { return [] }
        let midnight = calendar.startOfDay(for: date)
        return prayerNames.compactMap { name in
            let parts = times[name]?.split(separator: ":").compactMap { Int($0) } ?? []
            guard parts.count == 2 else { return nil }
            return Prayer(name: name, time: midnight.addingTimeInterval(TimeInterval(parts[0] * 3600 + parts[1] * 60)))
        }
    }

    func prayers(from date: Date, days count: Int) -> [Prayer] {
        (0..<count).flatMap { prayers(on: calendar.date(byAdding: .day, value: $0, to: date)!) }
    }
}

private func bundledSound(_ name: String) -> NSSound? {
    Bundle.main.url(forResource: name, withExtension: "mp3").flatMap { NSSound(contentsOf: $0, byReference: true) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private let timetable = Timetable()
    private let center = UNUserNotificationCenter.current()
    private let adhan = bundledSound("call_to_prayer") ?? NSSound(named: "Hero")
    private let chime = bundledSound("reminder") ?? NSSound(named: "Glass")
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    /// Notifications already shown, so a wake-up within the same minute can't repeat one.
    private var shown: Set<String> = []
    private var notificationsAllowed = true

    private let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = singapore
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// No notifications at all.
    private var paused: Bool {
        get { UserDefaults.standard.bool(forKey: "paused") }
        set { UserDefaults.standard.set(newValue, forKey: "paused") }
    }

    /// Pop-ups without sound.
    private var silent: Bool {
        get { UserDefaults.standard.bool(forKey: "silent") }
        set { UserDefaults.standard.set(newValue, forKey: "silent") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        center.delegate = self
        center.requestAuthorization(options: [.alert]) { _, _ in }
        // Earlier versions queued notifications with macOS in advance; clear any that are left.
        center.removeAllPendingNotificationRequests()
        enableLaunchAtLoginOnce()

        // Runs at the start of every minute (prayer times are whole minutes): shows any notification that's due
        // and refreshes the menu bar countdown.
        let nextMinute = Date(timeIntervalSinceReferenceDate: (Date().timeIntervalSinceReferenceDate / 60).rounded(.up) * 60)
        let timer = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        tick()

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tick()
        }
    }

    // MARK: Notifications

    private func tick() {
        let now = Date()
        if !paused {
            for prayer in timetable.prayers(on: now) where prayer.isNotified {
                showIfDue(id: "\(prayer.name)-reminder", at: prayer.time.addingTimeInterval(TimeInterval(-reminderMinutes * 60)),
                          now: now, title: "\(reminderMinutes) minutes to \(prayer.name)", sound: chime)
                showIfDue(id: prayer.name, at: prayer.time, now: now, title: "It's time for \(prayer.name).", sound: adhan)
            }
        }
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { self.notificationsAllowed = settings.authorizationStatus != .denied }
        }
        updateStatusTitle(now)
    }

    /// Shows a notification during the minute it's due. Anything later (the Mac was asleep) is skipped.
    private func showIfDue(id: String, at time: Date, now: Date, title: String, sound: NSSound?) {
        let key = "\(timetable.dayKey(time))-\(id)"
        guard now >= time, now < time.addingTimeInterval(60), !shown.contains(key) else { return }
        shown.insert(key)
        show(title: title, sound: sound)
    }

    private func show(title: String, sound: NSSound?) {
        let content = UNMutableNotificationContent()
        content.title = title
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        guard !silent, let sound else { return }
        sound.stop()
        sound.play()
    }

    private func stopSounds() {
        adhan?.stop()
        chime?.stop()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    /// Clicking a notification stops its sound.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { self.stopSounds() }
        completionHandler()
    }

    // MARK: Menu bar

    private func updateStatusTitle(_ now: Date) {
        let button = statusItem.button
        button?.image = NSImage(systemSymbolName: paused ? "bell.slash" : silent ? "speaker.slash" : "moon.stars",
                                accessibilityDescription: "Prayer Times")
        guard let next = nextPrayer(after: now) else {
            button?.title = " No timetable"
            return
        }
        let minutes = Int((next.time.timeIntervalSince(now) / 60).rounded(.up))
        let countdown = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        button?.title = " \(next.name) in \(countdown)"
    }

    private func nextPrayer(after now: Date) -> Prayer? {
        timetable.prayers(from: now, days: 2).first { $0.isNotified && $0.time > now }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let now = Date()
        let next = nextPrayer(after: now)
        let todays = timetable.prayers(on: now)

        menu.addItem(label(formatted(now, "EEEE, d MMMM")))
        if todays.isEmpty {
            menu.addItem(label("No prayer times for today"))
        }
        for prayer in todays {
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            item.attributedTitle = row(prayer, isNext: prayer.time == next?.time, isPast: prayer.time <= now)
            menu.addItem(item)
        }
        if let lastDay = timetable.lastDay, lastDay.timeIntervalSince(now) < 14 * 86_400 {
            menu.addItem(.separator())
            menu.addItem(label("⚠️ Timetable ends \(formatted(lastDay, "d MMM yyyy"))"))
        }

        menu.addItem(.separator())
        if !notificationsAllowed {
            menu.addItem(action("Notifications Are Off — Open Settings…", #selector(openNotificationSettings)))
        }
        menu.addItem(action("Silent (Pop-ups Only)", #selector(toggleSilent), on: silent))
        menu.addItem(action("Pause Notifications", #selector(togglePaused), on: paused))
        menu.addItem(action("Test 10-Minute Reminder", #selector(testReminder)))
        menu.addItem(action("Test Prayer Time", #selector(testPrayerTime)))
        menu.addItem(action("Launch at Login", #selector(toggleLaunchAtLogin), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Prayer Times", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func row(_ prayer: Prayer, isNext: Bool, isPast: Bool) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 170)]
        let size = NSFont.menuFont(ofSize: 0).pointSize
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: isNext ? .bold : .regular),
            .paragraphStyle: style,
        ]
        if isPast || !prayer.isNotified {
            attributes[.foregroundColor] = NSColor.secondaryLabelColor
        }
        return NSAttributedString(string: "\(prayer.name)\t\(clockFormatter.string(from: prayer.time))", attributes: attributes)
    }

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, on: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    private func formatted(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = singapore
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    // MARK: Actions

    @objc private func toggleSilent() {
        silent.toggle()
        if silent { stopSounds() }
        tick()
    }

    @objc private func togglePaused() {
        paused.toggle()
        tick()
    }

    private var testPrayerName: String { nextPrayer(after: Date())?.name ?? "Zohor" }

    @objc private func testReminder() {
        show(title: "\(reminderMinutes) minutes to \(testPrayerName)", sound: chime)
    }

    @objc private func testPrayerTime() {
        show(title: "It's time for \(testPrayerName).", sound: adhan)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
        }
    }

    @objc private func openNotificationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }

    private func enableLaunchAtLoginOnce() {
        guard !UserDefaults.standard.bool(forKey: "launchAtLoginConfigured") else { return }
        UserDefaults.standard.set(true, forKey: "launchAtLoginConfigured")
        try? SMAppService.mainApp.register()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
