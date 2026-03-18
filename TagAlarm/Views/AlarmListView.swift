import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @State private var showingAdd = false
    @State private var editingAlarm: Alarm?

    var body: some View {
        NavigationStack {
            Group {
                if alarmManager.alarms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "alarm")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No alarms yet")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(alarmManager.alarms) { alarm in
                            AlarmRow(alarm: alarm)
                                .contentShape(Rectangle())
                                .onTapGesture { editingAlarm = alarm }
                        }
                        .onDelete(perform: alarmManager.deleteAlarm)
                    }
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddAlarmView()
            }
            .sheet(item: $editingAlarm) { alarm in
                AddAlarmView(existing: alarm)
            }
        }
    }
}

struct AlarmRow: View {
    @EnvironmentObject var alarmManager: AlarmManager
    let alarm: Alarm

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .foregroundStyle(alarm.isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    if !alarm.name.isEmpty {
                        Text(alarm.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(alarm.repeatDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if !alarm.checkpointIDs.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "tag")
                            Text("\(alarm.checkpointIDs.count)")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in alarmManager.toggleAlarm(alarm) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
