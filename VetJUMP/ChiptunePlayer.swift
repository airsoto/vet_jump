import AVFoundation

final class ChiptunePlayer {
    static let shared = ChiptunePlayer()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isPlaying = false
    private init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        do { try engine.start() } catch { return }
        scheduleLoop()
        player.play()
    }

    func stop() { player.stop(); engine.stop(); isPlaying = false }

    private func scheduleLoop() {
        let melody: [Float] = [261.63, 329.63, 392.0, 523.25, 392.0, 329.63, 293.66, 349.23, 440.0, 587.33, 440.0, 349.23]
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 22_050 * 3) else { return }
        buffer.frameLength = buffer.frameCapacity
        let samples = buffer.floatChannelData![0]
        let samplesPerNote = Int(format.sampleRate * 0.25)
        for frame in 0..<Int(buffer.frameLength) {
            let noteIndex = (frame / samplesPerNote) % melody.count
            let phase = Float(frame % samplesPerNote) * melody[noteIndex] / Float(format.sampleRate)
            let square: Float = phase.truncatingRemainder(dividingBy: 1) < 0.5 ? 0.055 : -0.055
            samples[frame] = square
        }
        player.scheduleBuffer(buffer, completionHandler: { [weak self] in DispatchQueue.main.async { guard self?.isPlaying == true else { return }; self?.scheduleLoop() } })
    }
}
