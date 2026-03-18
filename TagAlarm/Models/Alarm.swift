import Foundation

enum Weekday: Int, Codable, CaseIterable, Comparable, Hashable {
    case monday = 2, tuesday = 3, wednesday = 4, thursday = 5
    case friday = 6, saturday = 7, sunday = 1

    var shortName: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }

    var letter: String {
        switch self {
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        case .sunday: "S"
        }
    }

    static var ordered: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        ordered.firstIndex(of: lhs)! < ordered.firstIndex(of: rhs)!
    }
}

enum AlarmSound: String, Codable, CaseIterable, Identifiable {
    case radar = "Radar"
    case beacon = "Beacon"
    case chimes = "Chimes"
    case signal = "Signal"
    case bulletin = "Bulletin"
    case classic = "Classic"

    var id: String { rawValue }

    var systemSoundID: UInt32 {
        switch self {
        case .radar: 1005
        case .beacon: 1015
        case .chimes: 1013
        case .signal: 1012
        case .bulletin: 1020
        case .classic: 1007
        }
    }
}

struct Alarm: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String = ""
    var hour: Int = 7
    var minute: Int = 0
    var repeatDays: Set<Weekday> = []
    var isEnabled: Bool = true
    var checkpointIDs: [UUID] = []
    var sound: AlarmSound = .radar

    var timeString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", h, minute, period)
    }

    var repeatDescription: String {
        if repeatDays.isEmpty { return "One time" }
        if repeatDays.count == 7 { return "Every day" }
        let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        if repeatDays == weekdays { return "Weekdays" }
        let weekend: Set<Weekday> = [.saturday, .sunday]
        if repeatDays == weekend { return "Weekends" }
        return repeatDays.sorted().map(\.shortName).joined(separator: ", ")
    }

    var dateForPicker: Date {
        get {
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            return Calendar.current.date(from: comps) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            hour = comps.hour ?? 7
            minute = comps.minute ?? 0
        }
    }
}
