import AVFoundation
import AudioToolbox
import UIKit

final class AudioManager: @unchecked Sendable {
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var player: AVAudioPlayer?
    private var repeatTimer: Timer?

    func playAlarm(sound: AlarmSound) {
        configureSession()

        // Try bundled custom sound file first
        if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") ??
            Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a") ??
            Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.numberOfLoops = -1
                player?.volume = 1.0
                player?.play()
                return
            } catch {
                print("[TagAlarm] Failed to load sound file: \(error)")
            }
        }

        // Generate a piercing alarm tone with AVAudioEngine
        startToneGenerator()
    }

    func stop() {
        player?.stop()
        player = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        stopToneGenerator()
    }

    // MARK: - Tone Generator

    private func startToneGenerator() {
        stopToneGenerator()

        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        // Generate a pulsing 800Hz tone (0.5s on, 0.3s off, repeating)
        let toneHz: Double = 800
        let onDuration: Double = 0.5
        let offDuration: Double = 0.3
        let cycleDuration = onDuration + offDuration
        let totalCycles = 60 // ~48 seconds of buffer, loops
        let totalFrames = AVAudioFrameCount(sampleRate * cycleDuration * Double(totalCycles))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return }
        buffer.frameLength = totalFrames

        guard let floatData = buffer.floatChannelData?[0] else { return }

        let onFrames = Int(sampleRate * onDuration)
        let offFrames = Int(sampleRate * offDuration)
        let cycleFrames = onFrames + offFrames

        for i in 0..<Int(totalFrames) {
            let posInCycle = i % cycleFrames
            if posInCycle < onFrames {
                // Tone on — dual frequency for urgency (800Hz + 1000Hz)
                let t = Double(i) / sampleRate
                let wave1 = sin(2.0 * .pi * toneHz * t)
                let wave2 = sin(2.0 * .pi * 1000.0 * t) * 0.6
                // Apply envelope to avoid clicks
                let envelope: Double
                if posInCycle < 200 {
                    envelope = Double(posInCycle) / 200.0 // fade in
                } else if posInCycle > onFrames - 200 {
                    envelope = Double(onFrames - posInCycle) / 200.0 // fade out
                } else {
                    envelope = 1.0
                }
                floatData[i] = Float((wave1 + wave2) * 0.8 * envelope)
            } else {
                floatData[i] = 0 // silence gap
            }
        }

        do {
            try engine.start()
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            playerNode.play()
            self.engine = engine
            self.playerNode = playerNode
        } catch {
            print("[TagAlarm] Audio engine failed: \(error), falling back to system sounds")
            fallbackToSystemSounds(sound: .radar)
        }

        // Also vibrate on a timer
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func stopToneGenerator() {
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
    }

    private func fallbackToSystemSounds(sound: AlarmSound) {
        AudioServicesPlaySystemSound(sound.systemSoundID)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(sound.systemSoundID)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    // MARK: - Session

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[TagAlarm] Audio session config failed: \(error)")
        }
    }
}
