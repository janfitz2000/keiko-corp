import SwiftUI

struct CheckpointSetupView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if alarmManager.checkpoints.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tag")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No checkpoints yet")
                            .foregroundStyle(.secondary)
                        Text("Add NFC tags around your home to create checkpoints")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(alarmManager.checkpoints) { cp in
                            NavigationLink {
                                EditCheckpointView(checkpoint: cp)
                            } label: {
                                CheckpointRow(checkpoint: cp)
                            }
                        }
                        .onDelete(perform: alarmManager.deleteCheckpoint)
                    }
                }
            }
            .navigationTitle("Checkpoints")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddCheckpointView()
            }
        }
    }
}

struct CheckpointRow: View {
    let checkpoint: Checkpoint

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: checkpoint.icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(checkpoint.name)
                    .font(.body)

                HStack(spacing: 8) {
                    if checkpoint.isPaired {
                        Label("Paired", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Not paired", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if checkpoint.isHold {
                        Label("\(checkpoint.holdMinutes)m hold", systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct AddCheckpointView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var nfcManager: NFCManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "tag"
    @State private var isHold = false
    @State private var holdMinutes = 5
    @State private var nfcTagID = ""
    @State private var showIconPicker = false

    private let icons = [
        "tag", "refrigerator", "door.left.hand.open", "envelope",
        "shower", "desktopcomputer", "fork.knife", "bed.double",
        "car", "figure.walk", "cup.and.saucer", "tshirt",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Fridge, Front Door", text: $name)

                    // Quick suggestions
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Checkpoint.examples, id: \.0) { example in
                                Button {
                                    name = example.0
                                    icon = example.1
                                } label: {
                                    Label(example.0, systemImage: example.1)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { ic in
                            Button {
                                icon = ic
                            } label: {
                                Image(systemName: ic)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(icon == ic ? Color.orange : Color(.systemGray5))
                                    .foregroundStyle(icon == ic ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    if nfcTagID.isEmpty {
                        Button {
                            nfcManager.scan(message: "Hold near the NFC tag for \(name.isEmpty ? "this checkpoint" : name)") { tagID in
                                nfcTagID = tagID
                            }
                        } label: {
                            Label("Scan NFC Tag", systemImage: "wave.3.right")
                        }
                    } else {
                        HStack {
                            Label("Tag paired", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Re-scan") {
                                nfcManager.scan { tagID in
                                    nfcTagID = tagID
                                }
                            }
                            .font(.caption)
                        }

                        Text("ID: \(nfcTagID)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let error = nfcManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("NFC Tag")
                } footer: {
                    Text("Place an NFC sticker at this location and scan it to pair.")
                }

                Section {
                    Toggle("Hold checkpoint", isOn: $isHold)

                    if isHold {
                        Stepper("Hold time: \(holdMinutes) min", value: $holdMinutes, in: 1...30)
                    }
                } footer: {
                    if isHold {
                        Text("After scanning this checkpoint, the alarm will re-trigger after \(holdMinutes) minutes unless you scan the next checkpoint or re-scan this one for more time.")
                    }
                }
            }
            .navigationTitle("Add Checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cp = Checkpoint(
                            name: name,
                            nfcTagID: nfcTagID,
                            icon: icon,
                            isHold: isHold,
                            holdMinutes: holdMinutes
                        )
                        alarmManager.addCheckpoint(cp)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct EditCheckpointView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var nfcManager: NFCManager
    @Environment(\.dismiss) private var dismiss

    @State var checkpoint: Checkpoint

    private let icons = [
        "tag", "refrigerator", "door.left.hand.open", "envelope",
        "shower", "desktopcomputer", "fork.knife", "bed.double",
        "car", "figure.walk", "cup.and.saucer", "tshirt",
    ]

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $checkpoint.name)
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(icons, id: \.self) { ic in
                        Button {
                            checkpoint.icon = ic
                        } label: {
                            Image(systemName: ic)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(checkpoint.icon == ic ? Color.orange : Color(.systemGray5))
                                .foregroundStyle(checkpoint.icon == ic ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("NFC Tag") {
                if checkpoint.isPaired {
                    HStack {
                        Label("Paired", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Re-scan") {
                            nfcManager.scan { tagID in
                                checkpoint.nfcTagID = tagID
                            }
                        }
                        .font(.caption)
                    }
                    Text("ID: \(checkpoint.nfcTagID)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        nfcManager.scan { tagID in
                            checkpoint.nfcTagID = tagID
                        }
                    } label: {
                        Label("Scan NFC Tag", systemImage: "wave.3.right")
                    }
                }
            }

            Section {
                Toggle("Hold checkpoint", isOn: $checkpoint.isHold)
                if checkpoint.isHold {
                    Stepper("Hold time: \(checkpoint.holdMinutes) min", value: $checkpoint.holdMinutes, in: 1...30)
                }
            }

            Section {
                Button("Delete Checkpoint", role: .destructive) {
                    alarmManager.checkpoints.removeAll { $0.id == checkpoint.id }
                    dismiss()
                }
            }
        }
        .navigationTitle("Edit Checkpoint")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    alarmManager.updateCheckpoint(checkpoint)
                    dismiss()
                }
            }
        }
    }
}
