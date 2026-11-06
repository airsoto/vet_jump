import AVFoundation

final class ChiptunePlayer {
    static let shared = ChiptunePlayer()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var loopBuffer: AVAudioPCMBuffer?
    private var isPlaying = false
    private init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play() {
        guard !isPlaying else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
        } catch { return }
        guard let buffer = makeLoopBuffer() else { engine.stop(); return }
        loopBuffer = buffer
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
        isPlaying = true
    }

    func stop() { player.stop(); engine.stop(); loopBuffer = nil; isPlaying = false }

    private func makeLoopBuffer() -> AVAudioPCMBuffer? {
        let melody: [Float] = [261.63, 329.63, 392.0, 523.25, 392.0, 329.63, 293.66, 349.23, 440.0, 587.33, 440.0, 349.23]
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 22_050 * 3) else { return nil }
        buffer.frameLength = buffer.frameCapacity
        let samples = buffer.floatChannelData![0]
        let samplesPerNote = Int(format.sampleRate * 0.25)
        for frame in 0..<Int(buffer.frameLength) {
            let noteIndex = (frame / samplesPerNote) % melody.count
            let phase = Float(frame % samplesPerNote) * melody[noteIndex] / Float(format.sampleRate)
            let square: Float = phase.truncatingRemainder(dividingBy: 1) < 0.5 ? 0.08 : -0.08
            samples[frame] = square
        }
        return buffer
    }
}
