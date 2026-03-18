import CoreNFC
import Combine

class NFCManager: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastTagID: String = ""
    @Published var errorMessage: String?

    private var session: NFCTagReaderSession?
    private var onScan: ((String) -> Void)?

    var isAvailable: Bool {
        NFCTagReaderSession.readingAvailable
    }

    func scan(message: String = "Hold your iPhone near the NFC tag", completion: @escaping (String) -> Void) {
        guard isAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }
        guard !isScanning else { return }

        onScan = completion
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil)
        session?.alertMessage = message
        session?.begin()
        isScanning = true
        errorMessage = nil
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
                    break // user dismissed, no error
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.errorMessage = "Scan timed out. Tap to try again."
                default:
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found. Try again.")
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
        switch tag {
        case .miFare(let t):
            return t.identifier.map { String(format: "%02x", $0) }.joined()
        case .iso7816(let t):
            return t.identifier.map { String(format: "%02x", $0) }.joined()
        case .iso15693(let t):
            return t.identifier.map { String(format: "%02x", $0) }.joined()
        case .feliCa(let t):
            return t.currentIDm.map { String(format: "%02x", $0) }.joined()
        @unknown default:
            return ""
        }
    }
}
