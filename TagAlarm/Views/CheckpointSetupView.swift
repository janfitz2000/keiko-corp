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
                                CheckpointFormView(existing: cp)
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
                CheckpointFormView()
            }
        }
    }
}

// MARK: - Row

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

                HStack(spacing: 8) {
                    Label(
                        checkpoint.isPaired ? "Paired" : "Not paired",
                        systemImage: checkpoint.isPaired ? "checkmark.circle.fill" : "exclamationmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(checkpoint.isPaired ? .green : .red)

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

// MARK: - Icon Picker

struct IconPicker: View {
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(Checkpoint.icons, id: \.self) { ic in
                Button {
                    selection = ic
                } label: {
                    Image(systemName: ic)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(selection == ic ? Color.orange : Color(.systemGray5))
                        .foregroundStyle(selection == ic ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Unified Add/Edit Form

struct CheckpointFormView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var nfcManager: NFCManager
    @Environment(\.dismiss) private var dismiss

    @State private var checkpoint: Checkpoint
    private let isEditing: Bool

    init(existing: Checkpoint? = nil) {
        if let existing {
            _checkpoint = State(initialValue: existing)
            isEditing = true
        } else {
            _checkpoint = State(initialValue: Checkpoint(name: ""))
            isEditing = false
        }
    }

    var body: some View {
        let form = Form {
            Section("Name") {
                TextField("e.g. Fridge, Front Door", text: $checkpoint.name)

                if !isEditing {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Checkpoint.suggestions, id: \.0) { name, icon in
                                Button {
                                    checkpoint.name = name
                                    checkpoint.icon = icon
                                } label: {
                                    Label(name, systemImage: icon)
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
            }

            Section("Icon") {
                IconPicker(selection: $checkpoint.icon)
            }

            Section {
                nfcSection
            } header: {
                Text("NFC Tag")
            } footer: {
                if !checkpoint.isPaired {
                    Text("Place an NFC sticker at this location and scan it to pair.")
                }
            }

            Section {
                Toggle("Hold checkpoint", isOn: $checkpoint.isHold)

                if checkpoint.isHold {
                    Stepper("Hold time: \(checkpoint.holdMinutes) min", value: $checkpoint.holdMinutes, in: 1...30)
                }
            } footer: {
                if checkpoint.isHold {
                    Text("The alarm will re-trigger after \(checkpoint.holdMinutes) minutes unless you scan the next checkpoint or re-scan this one.")
                }
            }

            if isEditing {
                Section {
                    Button("Delete Checkpoint", role: .destructive) {
                        alarmManager.deleteCheckpoint(id: checkpoint.id)
                        dismiss()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)

        if isEditing {
            form
                .navigationTitle("Edit Checkpoint")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            alarmManager.updateCheckpoint(checkpoint)
                            dismiss()
                        }
                    }
                }
        } else {
            NavigationStack {
                form
                    .navigationTitle("Add Checkpoint")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                alarmManager.addCheckpoint(checkpoint)
                                dismiss()
                            }
                            .disabled(checkpoint.name.isEmpty || !checkpoint.isPaired)
                        }
                    }
            }
        }
    }

    // MARK: - NFC Section

    @ViewBuilder
    private var nfcSection: some View {
        if checkpoint.isPaired {
            HStack {
                Label("Tag paired", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("Re-scan") {
                    nfcManager.scan { checkpoint.nfcTagID = $0 }
                }
                .font(.caption)
            }
            Text("ID: \(checkpoint.nfcTagID)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Button {
                let label = checkpoint.name.isEmpty ? "this checkpoint" : checkpoint.name
                nfcManager.scan(message: "Hold near the NFC tag for \(label)") { checkpoint.nfcTagID = $0 }
            } label: {
                Label("Scan NFC Tag", systemImage: "wave.3.right")
            }
        }

        if let error = nfcManager.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
