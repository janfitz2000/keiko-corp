import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmManager: AlarmManager

    var body: some View {
        ZStack {
            TabView {
                AlarmListView()
                    .tabItem {
                        Label("Alarms", systemImage: "alarm")
                    }

                CheckpointSetupView()
                    .tabItem {
                        Label("Checkpoints", systemImage: "tag")
                    }

                LocationView()
                    .tabItem {
                        Label("Location", systemImage: "location")
                    }
            }

            // Full-screen active alarm overlay
            if alarmManager.activeAlarm != nil {
                ActiveAlarmView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: alarmManager.activeAlarm != nil)
    }
}
