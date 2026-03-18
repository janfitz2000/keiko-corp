import CoreNFC
import Combine

class NFCManager: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastTagID: String = ""
    @Published var errorMessage: String?

    private var session: NFCTagReaderSession?
    private var onScan: ((String) -> Void)?
    private var continuous = false
    private var continuousMessage = ""

    var isAvailable: Bool {
        NFCTagReaderSession.readingAvailable
    }

    /// One-shot scan (used for checkpoint setup).
    func scan(message: String = "Hold your iPhone near the NFC tag", completion: @escaping (String) -> Void) {
        guard isAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }
        guard !isScanning else { return }

        continuous = false
        onScan = completion
        startSession(message: message)
    }

    /// Start continuous scanning (used during active alarm).
    /// Automatically restarts after each scan or timeout.
    func startContinuousScanning(message: String = "Hold near NFC tag", onScan: @escaping (String) -> Void) {
        guard isAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }

        continuous = true
        continuousMessage = message
        self.onScan = onScan
        startSession(message: message)
    }

    /// Stop continuous scanning.
    func stopContinuousScanning() {
        continuous = false
        onScan = nil
        session?.invalidate()
        session = nil
        isScanning = false
    }

    /// Update the NFC sheet message (e.g. when checkpoint changes).
    func updateMessage(_ message: String) {
        continuousMessage = message
        session?.alertMessage = message
    }

    private func startSession(message: String) {
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil)
        session?.alertMessage = message
        session?.begin()
        DispatchQueue.main.async { self.isScanning = true }
        errorMessage = nil
    }

    private func restartAfterDelay() {
        guard continuous, onScan != nil else { return }
        // Small delay required — can't start a new session from within invalidation callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.continuous, self.onScan != nil else { return }
            self.startSession(message: self.continuousMessage)
        }
    }
}

extension NFCManager: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User swiped down to dismiss — stop continuous mode
                    self.continuous = false
                    return
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.errorMessage = nil // silent restart in continuous mode
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    break
                default:
                    self.errorMessage = error.localizedDescription
                }
            }

            self.restartAfterDelay()
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            if error != nil {
                session.invalidate(errorMessage: "Connection failed. Try again.")
                return
            }

            let tagID = self?.extractTagID(from: tag) ?? ""

            if tagID.isEmpty {
                session.invalidate(errorMessage: "Could not read this tag.")
                return
            }

            session.alertMessage = "Tag scanned!"
            session.invalidate()

            DispatchQueue.main.async {
                self?.lastTagID = tagID
                self?.isScanning = false
                self?.errorMessage = nil
                self?.onScan?(tagID)
            }
        }
    }

    private func extractTagID(from tag: NFCTag) -> String {
        let data: Data? = switch tag {
        case .miFare(let t): t.identifier
        case .iso7816(let t): t.identifier
        case .iso15693(let t): t.identifier
        case .feliCa(let t): t.currentIDm
        @unknown default: nil
        }
        return data?.map { String(format: "%02x", $0) }.joined() ?? ""
    }
}
