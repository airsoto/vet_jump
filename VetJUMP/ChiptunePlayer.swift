import AVFoundation

final class ChiptunePlayer {
    static let shared = ChiptunePlayer()

    private let mutedKey = "VetJUMP.musicMuted"
    private var player: AVAudioPlayer?
    private var currentTrack: String?
    private var currentSelectionKey: String?
    private var shouldResumeAfterQuestion = false

    private(set) var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: mutedKey) }
    }

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: mutedKey)
    }

    func playMenu() {
        select(tracks: ["02 - it is dangerous to be lonely without a sword (chiptune)"], key: "menu")
    }

    func updateGameMusic(level: Int, platform: Int, infinite: Bool) {
        let selection = selection(for: level, platform: platform, infinite: infinite)
        select(tracks: selection.tracks, key: selection.key)
    }

    func stopForQuestion() {
        shouldResumeAfterQuestion = currentTrack != nil
        player?.stop()
        player = nil
    }

    func resumeAfterQuestion() {
        guard shouldResumeAfterQuestion else { return }
        shouldResumeAfterQuestion = false
        playCurrentTrack()
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        guard !isMuted else { return }
        player?.play()
    }

    @discardableResult
    func toggleMuted() -> Bool {
        isMuted.toggle()
        if isMuted {
            player?.stop()
            player = nil
        } else {
            playCurrentTrack()
        }
        return isMuted
    }

    private func select(tracks: [String], key: String) {
        guard !tracks.isEmpty else { return }
        if currentSelectionKey == key, player?.isPlaying == true { return }
        currentSelectionKey = key
        currentTrack = tracks.randomElement()
        shouldResumeAfterQuestion = false
        playCurrentTrack()
    }

    private func playCurrentTrack() {
        guard !isMuted, let currentTrack, let url = Bundle.main.url(forResource: currentTrack, withExtension: "m4a", subdirectory: "Music") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = 0.62
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            player = audioPlayer
        } catch {
            player = nil
        }
    }

    private func selection(for level: Int, platform: Int, infinite: Bool) -> (key: String, tracks: [String]) {
        if infinite { return ("infinite", allTracks()) }
        switch level {
        case 1 where platform >= 75:
            return ("level-1-late", ["14 - return to the planet of the lobsters", "25 - i have no joystick and i must press start"])
        case 1:
            return ("level-1", ["01 - super mushroom eater", "08 - quest of magic cowboy dude (chiptune)", "07 - the town where i got the magic bottle (chiptune)", "12 - youthful elf seeking adventure (chiptune)"])
        case 2:
            return ("level-2", ["10 - wandering around looking for ammunition", "07 - the town where i got the magic bottle (chiptune)", "12 - youthful elf seeking adventure (chiptune)"])
        case 3:
            return ("level-3", ["29 - in the land of morose where the ladies smoke cloves", "32 - famicommunist manifesto"])
        case 4:
            return ("level-4", ["39 - Dinosaur Spirit Guide (Sega-style FM Synth Remix)", "35 - The Creeper", "34 - dad got me a new nes game but it sucks"])
        default:
            return ("level-5", ["24 - hungry ghost fever", "52 - Castle of the Goblin Queen (Sega-style FM Synth Remix)"])
        }
    }

    private func allTracks() -> [String] {
        Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: "Music")?.map { $0.deletingPathExtension().lastPathComponent } ?? []
    }
}
