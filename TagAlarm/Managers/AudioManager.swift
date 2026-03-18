import AVFoundation
import AudioToolbox

class AudioManager {
    private var player: AVAudioPlayer?
    private var repeatTimer: Timer?

    func playAlarm(sound: AlarmSound) {
        configureSession()

        // Try to load a bundled sound file first (for custom sounds)
        if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") ??
            Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a") ??
            Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.numberOfLoops = -1 // infinite loop
                player?.volume = 1.0
                player?.play()
                return
            } catch {}
        }

        // Fallback: use system sounds on a timer
        AudioServicesPlaySystemSound(sound.systemSoundID)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        repeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(sound.systemSoundID)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }
}
