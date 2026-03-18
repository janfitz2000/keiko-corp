import Foundation
import UserNotifications
import Combine

@MainActor
class AlarmManager: ObservableObject {
    // MARK: - Published State

    @Published var alarms: [Alarm] = []
    @Published var checkpoints: [Checkpoint] = []

    // Active alarm state
    @Published var activeAlarm: Alarm?
    @Published var currentCheckpointIndex: Int = 0
    @Published var isAlarmSounding: Bool = false
    @Published var holdTimeRemaining: TimeInterval = 0
    @Published var activeHoldCheckpointID: UUID?

    // MARK: - Private

    private let audioManager = AudioManager()
    private var holdTimer: Timer?
    private let notificationDelegate = NotificationDelegate()

    private var alarmsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("alarms.json")
    }

    private var checkpointsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("checkpoints.json")
    }

    // MARK: - Init

    init() {
        load()
        setupNotifications()
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: alarmsURL),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
        }
        if let data = try? Data(contentsOf: checkpointsURL),
           let decoded = try? JSONDecoder().decode([Checkpoint].self, from: data) {
            checkpoints = decoded
        }
    }

    private func saveAlarms() {
        if let data = try? JSONEncoder().encode(alarms) {
            try? data.write(to: alarmsURL)
        }
        scheduleAllNotifications()
    }

    private func saveCheckpoints() {
        if let data = try? JSONEncoder().encode(checkpoints) {
            try? data.write(to: checkpointsURL)
        }
    }

    // MARK: - Alarm CRUD

    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        saveAlarms()
    }

    func updateAlarm(_ alarm: Alarm) {
        guard let i = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[i] = alarm
        saveAlarms()
    }

    func deleteAlarm(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        saveAlarms()
    }

    func toggleAlarm(_ alarm: Alarm) {
        guard let i = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[i].isEnabled.toggle()
        saveAlarms()
    }

    // MARK: - Checkpoint CRUD

    func addCheckpoint(_ cp: Checkpoint) {
        checkpoints.append(cp)
        saveCheckpoints()
    }

    func updateCheckpoint(_ cp: Checkpoint) {
        guard let i = checkpoints.firstIndex(where: { $0.id == cp.id }) else { return }
        checkpoints[i] = cp
        saveCheckpoints()
    }

    func deleteCheckpoint(at offsets: IndexSet) {
        let ids = offsets.map { checkpoints[$0].id }
        checkpoints.remove(atOffsets: offsets)
        for i in alarms.indices {
            alarms[i].checkpointIDs.removeAll { ids.contains($0) }
        }
        saveCheckpoints()
        saveAlarms()
    }

    func checkpoint(for id: UUID) -> Checkpoint? {
        checkpoints.first { $0.id == id }
    }

    // MARK: - Active Alarm Flow

    func triggerAlarm(_ alarm: Alarm) {
        activeAlarm = alarm
        currentCheckpointIndex = 0
        activeHoldCheckpointID = nil
        holdTimeRemaining = 0
        isAlarmSounding = true
        audioManager.playAlarm(sound: alarm.sound)
    }

    /// Called when an NFC tag is scanned during an active alarm.
    func onTagScanned(_ tagID: String) {
        guard let alarm = activeAlarm else { return }

        // Check if re-scanning a hold checkpoint
        if let holdID = activeHoldCheckpointID,
           let holdCP = checkpoint(for: holdID),
           holdCP.nfcTagID == tagID {
            resetHoldTimer(minutes: holdCP.holdMinutes)
            audioManager.stop()
            isAlarmSounding = false
            return
        }

        // Check if it matches the current checkpoint
        guard currentCheckpointIndex < alarm.checkpointIDs.count else { return }
        let currentID = alarm.checkpointIDs[currentCheckpointIndex]
        guard let cp = checkpoint(for: currentID), cp.nfcTagID == tagID else { return }

        // Checkpoint matched
        audioManager.stop()
        isAlarmSounding = false
        cancelHoldTimer()

        if cp.isHold {
            // This is a hold checkpoint — start the hold timer
            activeHoldCheckpointID = cp.id
            startHoldTimer(minutes: cp.holdMinutes)
        } else {
            activeHoldCheckpointID = nil
        }

        currentCheckpointIndex += 1

        // Check if all checkpoints cleared
        if currentCheckpointIndex >= alarm.checkpointIDs.count {
            dismissAlarm()
        }
    }

    func dismissAlarm() {
        audioManager.stop()
        cancelHoldTimer()
        activeAlarm = nil
        currentCheckpointIndex = 0
        isAlarmSounding = false
        holdTimeRemaining = 0
        activeHoldCheckpointID = nil
    }

    // MARK: - Hold Timer

    private func startHoldTimer(minutes: Int) {
        holdTimeRemaining = TimeInterval(minutes * 60)
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.holdTimeRemaining -= 1
                if self.holdTimeRemaining <= 0 {
                    self.cancelHoldTimer()
                    if let alarm = self.activeAlarm {
                        self.isAlarmSounding = true
                        self.audioManager.playAlarm(sound: alarm.sound)
                    }
                }
            }
        }
    }

    private func resetHoldTimer(minutes: Int) {
        cancelHoldTimer()
        startHoldTimer(minutes: minutes)
    }

    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for alarm in alarms where alarm.isEnabled {
            if alarm.repeatDays.isEmpty {
                scheduleNotification(for: alarm, weekday: nil)
            } else {
                for day in alarm.repeatDays {
                    scheduleNotification(for: alarm, weekday: day)
                }
            }
        }
    }

    private func scheduleNotification(for alarm: Alarm, weekday: Weekday?) {
        let content = UNMutableNotificationContent()
        content.title = alarm.name.isEmpty ? "Alarm" : alarm.name
        content.body = "Time to get up! Open the app and scan your checkpoints."
        content.sound = .default
        content.userInfo = ["alarmID": alarm.id.uuidString]

        var comps = DateComponents()
        comps.hour = alarm.hour
        comps.minute = alarm.minute
        if let weekday { comps.weekday = weekday.rawValue }

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: weekday != nil)
        let id = weekday != nil ? "\(alarm.id)-\(weekday!.rawValue)" : alarm.id.uuidString

        center_add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func center_add(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request)
    }

    func handleNotification(alarmID: String) {
        guard let alarm = alarms.first(where: { $0.id.uuidString == alarmID && $0.isEnabled }) else { return }
        triggerAlarm(alarm)
    }
}
