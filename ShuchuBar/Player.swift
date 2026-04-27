import AVFoundation
import SwiftUI

class TBPlayer: ObservableObject {
    private var windupSound: AVAudioPlayer?
    private var dingSound: AVAudioPlayer?
    private var isInitialized = false

    @AppStorage("soundEnabled") var soundEnabled: Bool = Default.soundEnabled

    private func loadSound(fileName: String) -> AVAudioPlayer {
        guard let asset = NSDataAsset(name: fileName) else {
            fatalError("Missing sound asset: \(fileName)")
        }
        let wav = AVFileType.wav.rawValue
        do {
            return try AVAudioPlayer(data: asset.data, fileTypeHint: wav)
        } catch {
            fatalError("Error loading sound: \(error)")
        }
    }

    func initPlayers() {
        if isInitialized { return }
        windupSound = loadSound(fileName: "windup")
        dingSound = loadSound(fileName: "ding")
        windupSound?.prepareToPlay()
        dingSound?.prepareToPlay()
        isInitialized = true
    }

    private func ensureInitialized() {
        if !isInitialized {
            initPlayers()
        }
    }

    func playWindup() {
        ensureInitialized()
        guard soundEnabled else { return }
        windupSound?.currentTime = 0
        DispatchQueue.main.async { [weak self] in
            self?.windupSound?.play()
        }
    }

    func playDing() {
        ensureInitialized()
        guard soundEnabled else { return }
        dingSound?.currentTime = 0
        DispatchQueue.main.async { [weak self] in
            self?.dingSound?.play()
        }
    }

    func startTicking(isPaused: Bool = false) {
        _ = isPaused
    }

    func stopTicking() { }

    func deinitPlayers() {
        if isInitialized {
            windupSound?.stop()
            dingSound?.stop()
        }
        windupSound = nil
        dingSound = nil
        isInitialized = false
    }
}
