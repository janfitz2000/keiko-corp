import Foundation

struct Checkpoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var nfcTagID: String = ""
    var icon: String = "tag"
    var isHold: Bool = false
    var holdMinutes: Int = 5

    var isPaired: Bool { !nfcTagID.isEmpty }

    static let icons = [
        "tag", "refrigerator", "door.left.hand.open", "envelope",
        "shower", "desktopcomputer", "fork.knife", "bed.double",
        "car", "figure.walk", "cup.and.saucer", "tshirt",
    ]

    static let suggestions: [(String, String)] = [
        ("Fridge", "refrigerator"),
        ("Front Door", "door.left.hand.open"),
        ("Postbox", "envelope"),
        ("Bathroom", "shower"),
        ("Desk", "desktopcomputer"),
        ("Kitchen", "fork.knife"),
    ]
}
