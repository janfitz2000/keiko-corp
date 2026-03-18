import SwiftUI

struct AddAlarmView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @Environment(\.dismiss) private var dismiss

    @State private var alarm: Alarm
    private let isEditing: Bool

    init(existing: Alarm? = nil) {
        if let existing {
            _alarm = State(initialValue: existing)
            isEditing = true
        } else {
            _alarm = State(initialValue: Alarm())
            isEditing = false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Time picker
                Section {
                    DatePicker("Time", selection: $alarm.dateForPicker, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                // Name
                Section {
                    TextField("Alarm name", text: $alarm.name)
                }

                // Repeat days
                Section("Repeat") {
                    DayPicker(selectedDays: $alarm.repeatDays)
                }

                // Sound
                Section("Sound") {
                    Picker("Sound", selection: $alarm.sound) {
                        ForEach(AlarmSound.allCases) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Checkpoints
                Section {
                    if alarm.checkpointIDs.isEmpty {
                        Text("No checkpoints — alarm can be dismissed normally")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(Array(alarm.checkpointIDs.enumerated()), id: \.element) { index, cpID in
                            if let cp = alarmManager.checkpoint(for: cpID) {
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.orange)
                                        .clipShape(Circle())

                                    Image(systemName: cp.icon)
                                        .foregroundStyle(.orange)
                                    Text(cp.name)
                                    Spacer()
                                    if cp.isHold {
                                        Text("\(cp.holdMinutes)m hold")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .onMove { from, to in
                            alarm.checkpointIDs.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { offsets in
                            alarm.checkpointIDs.remove(atOffsets: offsets)
                        }
                    }

                    // Add checkpoint picker
                    let available = alarmManager.checkpoints.filter {
                        $0.isPaired && !alarm.checkpointIDs.contains($0.id)
                    }
                    if !available.isEmpty {
                        Menu {
                            ForEach(available) { cp in
                                Button {
                                    alarm.checkpointIDs.append(cp.id)
                                } label: {
                                    Label(cp.name, systemImage: cp.icon)
                                }
                            }
                        } label: {
                            Label("Add checkpoint", systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text("NFC Checkpoints")
                } footer: {
                    Text("Drag to reorder. You must scan them in this sequence to dismiss the alarm.")
                }

                // Delete
                if isEditing {
                    Section {
                        Button("Delete Alarm", role: .destructive) {
                            alarmManager.deleteAlarm(id: alarm.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Alarm" : "New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isEditing {
                            alarmManager.updateAlarm(alarm)
                        } else {
                            alarmManager.addAlarm(alarm)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DayPicker: View {
    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.ordered, id: \.self) { day in
                Button {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                } label: {
                    Text(day.letter)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(selectedDays.contains(day) ? Color.orange : Color(.systemGray5))
                        .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
