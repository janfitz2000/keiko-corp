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

    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var alarmsURL: URL { docsDir.appendingPathComponent("alarms.json") }
    private var checkpointsURL: URL { docsDir.appendingPathComponent("checkpoints.json") }
    private var activeAlarmURL: URL { docsDir.appendingPathComponent("active_alarm.json") }

    // MARK: - Init

    init() {
        load()
        setupNotifications()
        restoreActiveAlarm()
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

    // MARK: - Active Alarm Persistence

    private struct ActiveAlarmState: Codable {
        let alarmID: UUID
        let checkpointIndex: Int
        let holdCheckpointID: UUID?
    }

    private func persistActiveAlarm() {
        guard let alarm = activeAlarm else {
            try? FileManager.default.removeItem(at: activeAlarmURL)
            return
        }
        let state = ActiveAlarmState(
            alarmID: alarm.id,
            checkpointIndex: currentCheckpointIndex,
            holdCheckpointID: activeHoldCheckpointID
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: activeAlarmURL)
        }
    }

    private func restoreActiveAlarm() {
        guard let data = try? Data(contentsOf: activeAlarmURL),
              let state = try? JSONDecoder().decode(ActiveAlarmState.self, from: data),
              let alarm = alarms.first(where: { $0.id == state.alarmID })
        else { return }

        // Re-trigger the alarm — user killed the app to try to escape
        activeAlarm = alarm
        currentCheckpointIndex = state.checkpointIndex
        activeHoldCheckpointID = state.holdCheckpointID
        isAlarmSounding = true
        audioManager.playAlarm(sound: alarm.sound)
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

    func deleteAlarm(id: UUID) {
        alarms.removeAll { $0.id == id }
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

    func deleteCheckpoint(id: UUID) {
        checkpoints.removeAll { $0.id == id }
        for i in alarms.indices {
            alarms[i].checkpointIDs.removeAll { $0 == id }
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
        persistActiveAlarm()
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
            activeHoldCheckpointID = cp.id
            startHoldTimer(minutes: cp.holdMinutes)
        } else {
            activeHoldCheckpointID = nil
        }

        currentCheckpointIndex += 1
        persistActiveAlarm()

        if currentCheckpointIndex >= alarm.checkpointIDs.count {
            dismissAlarm()
        }
    }

    func dismissAlarm() {
        // Disable one-time alarms after they fire
        if let alarm = activeAlarm, alarm.repeatDays.isEmpty {
            if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
                alarms[i].isEnabled = false
                saveAlarms()
            }
        }

        audioManager.stop()
        cancelHoldTimer()
        activeAlarm = nil
        currentCheckpointIndex = 0
        isAlarmSounding = false
        holdTimeRemaining = 0
        activeHoldCheckpointID = nil
        persistActiveAlarm() // clears the file
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

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }

    func handleNotification(alarmID: String) {
        guard let alarm = alarms.first(where: { $0.id.uuidString == alarmID && $0.isEnabled }) else { return }
        triggerAlarm(alarm)
    }
}
