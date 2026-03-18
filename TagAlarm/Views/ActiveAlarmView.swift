import SwiftUI

struct ActiveAlarmView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var nfcManager: NFCManager

    // Live clock
    @State private var currentTime = Date()
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Wrong-tag flash overlay
            if alarmManager.lastScanResult == .wrongTag {
                Color.red.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack(spacing: 32) {
                Spacer()

                // Live clock
                Text(currentTime, format: .dateTime.hour().minute())
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .onReceive(clockTimer) { currentTime = $0 }

                // Alarm name
                if let alarm = alarmManager.activeAlarm, !alarm.name.isEmpty {
                    Text(alarm.name)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Scan result feedback
                if let result = alarmManager.lastScanResult {
                    scanFeedback(result)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Checkpoint progress
                if let alarm = alarmManager.activeAlarm, !alarm.checkpointIDs.isEmpty {
                    checkpointProgress(alarm: alarm)
                }

                // Hold timer
                if alarmManager.holdTimeRemaining > 0 && !alarmManager.isAlarmSounding {
                    holdTimerView
                }

                // Scan button
                if let alarm = alarmManager.activeAlarm {
                    scanSection(alarm: alarm)
                }

                Spacer()
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.3), value: alarmManager.lastScanResult != nil)
    }

    // MARK: - Scan Feedback

    @ViewBuilder
    private func scanFeedback(_ result: ScanResult) -> some View {
        switch result {
        case .wrongTag:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                Text("Wrong tag! Find the right one.")
            }
            .font(.headline)
            .foregroundStyle(.red)
            .padding()
            .background(Color.red.opacity(0.15))
            .clipShape(Capsule())

        case .success:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Checkpoint cleared!")
            }
            .font(.headline)
            .foregroundStyle(.green)
            .padding()
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())

        case .holdReset:
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                Text("Timer reset — more time added")
            }
            .font(.headline)
            .foregroundStyle(.orange)
            .padding()
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
        }
    }

    // MARK: - Checkpoint Progress

    @ViewBuilder
    private func checkpointProgress(alarm: Alarm) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(alarm.checkpointIDs.enumerated()), id: \.offset) { index, _ in
                    let done = index < alarmManager.currentCheckpointIndex
                    let current = index == alarmManager.currentCheckpointIndex

                    Circle()
                        .fill(done ? Color.green : (current ? Color.orange : Color.gray.opacity(0.3)))
                        .frame(width: 12, height: 12)
                        .overlay {
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                    if index < alarm.checkpointIDs.count - 1 {
                        Rectangle()
                            .fill(done ? Color.green : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal, 32)

            // Current checkpoint label
            if alarmManager.currentCheckpointIndex < alarm.checkpointIDs.count,
               let cp = alarmManager.checkpoint(for: alarm.checkpointIDs[alarmManager.currentCheckpointIndex]) {
                HStack(spacing: 8) {
                    Image(systemName: cp.icon)
                    Text(cp.name)
                }
                .font(.headline)
                .foregroundStyle(.orange)
            } else if alarmManager.currentCheckpointIndex >= alarm.checkpointIDs.count {
                Text("All checkpoints cleared!")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Hold Timer

    private var holdTimerView: some View {
        VStack(spacing: 8) {
            let mins = Int(alarmManager.holdTimeRemaining) / 60
            let secs = Int(alarmManager.holdTimeRemaining) % 60

            Text(String(format: "%d:%02d", mins, secs))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(.orange)

            Text("until alarm rings again")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            if let holdID = alarmManager.activeHoldCheckpointID,
               let cp = alarmManager.checkpoint(for: holdID) {
                Button {
                    scanForTag { tagID in
                        alarmManager.onTagScanned(tagID)
                    }
                } label: {
                    Label("Re-scan \(cp.name) for more time", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Scan Button

    @ViewBuilder
    private func scanSection(alarm: Alarm) -> some View {
        if alarm.checkpointIDs.isEmpty {
            Button {
                alarmManager.dismissAlarm()
            } label: {
                Text("Dismiss")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
        } else if alarmManager.currentCheckpointIndex < alarm.checkpointIDs.count {
            let cpID = alarm.checkpointIDs[alarmManager.currentCheckpointIndex]
            let cp = alarmManager.checkpoint(for: cpID)

            Button {
                scanForTag { tagID in
                    alarmManager.onTagScanned(tagID)
                }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 40))
                        .symbolEffect(.variableColor.iterative, isActive: alarmManager.isAlarmSounding)

                    Text("Scan \(cp?.name ?? "Tag")")
                        .font(.title2.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    alarmManager.isAlarmSounding
                        ? Color.red
                        : Color.orange
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .disabled(nfcManager.isScanning)
            .padding(.horizontal)
        }
    }

    // MARK: - NFC

    private func scanForTag(completion: @escaping (String) -> Void) {
        guard !nfcManager.isScanning else { return }

        let cpName: String = {
            guard let alarm = alarmManager.activeAlarm,
                  alarmManager.currentCheckpointIndex < alarm.checkpointIDs.count,
                  let cp = alarmManager.checkpoint(for: alarm.checkpointIDs[alarmManager.currentCheckpointIndex])
            else { return "NFC tag" }
            return cp.name
        }()

        nfcManager.scan(message: "Hold near \(cpName) tag") { tagID in
            completion(tagID)
        }
    }
}
