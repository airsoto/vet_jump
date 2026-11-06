import SpriteKit
import CoreMotion

protocol GameSceneDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didUpdateHUD score: Int, platform: Int, lives: Int, level: Int, energy: CGFloat)
    func gameScene(_ scene: GameScene, requestExam kind: ExamKind)
    func gameSceneDidFinishLevel(_ scene: GameScene)
    func gameSceneDidEndGame(_ scene: GameScene)
}

final class GameScene: SKScene {
    private enum State { case ready, charging, jumping, paused, finished }
    private enum PlayerExpression { case neutral, charging, ascending, falling, landing }
    private struct Motion { let axis: CGVector; let amplitude: CGFloat; let period: TimeInterval; let origin: CGPoint }
    private struct Fruit { let kind: FruitKind; let platformIndex: Int; let node: SKLabelNode }

    weak var gameDelegate: GameSceneDelegate?
    var level = 1; var platformIndex = 0; var score = 0; var lives = 1; var isInfinite = false
    private let player = SKShapeNode(rectOf: CGSize(width: 28, height: 28), cornerRadius: 5)
    private let leftEye = SKShapeNode(circleOfRadius: 5)
    private let rightEye = SKShapeNode(circleOfRadius: 5)
    private let leftPupil = SKShapeNode(circleOfRadius: 2.25)
    private let rightPupil = SKShapeNode(circleOfRadius: 2.25)
    private let mouth = SKShapeNode()
    private let leftBrow = SKShapeNode()
    private let rightBrow = SKShapeNode()
    private let preview = SKShapeNode(); private let landingMarker = SKShapeNode(circleOfRadius: 9)
    private let gravity: CGFloat = 1_800; private let minimumPower: CGFloat = 0.13; private let chargeDuration: TimeInterval = 1.2
    private var state: State = .ready; private var chargingSince: TimeInterval = 0; private var power: CGFloat = 0
    private var velocity = CGVector.zero; private var previousPosition = CGPoint.zero; private var lastUpdate: TimeInterval = 0; private var elapsed: TimeInterval = 0
    private var glideEnergy: CGFloat = 1; private var touchHeld = false; private var launchPlatform = 0; private var standingPlatform: Int?; private var rescueFromFall = false; private var zeroLifeFallCount = 0
    private var playerExpression: PlayerExpression = .neutral; private var landingExpressionEndsAt: TimeInterval = 0
    private var platforms: [SKSpriteNode] = []; private var motions: [Int: Motion] = [:]; private var fruits: [Fruit] = []; private var collectedFruitPlatforms = Set<Int>()
    private let motionManager = CMMotionManager(); private var motionBaseline: CMAcceleration?; private var calibratedTilt = CGVector.zero
    private(set) var pendingFruit: FruitKind?
    var isGameOver: Bool { state == .finished }

    override func didMove(to view: SKView) { backgroundColor = themeColor; setupPlayer(); startMotion() }
    override func willMove(from view: SKView) { motionManager.stopDeviceMotionUpdates() }
    var themeColor: SKColor { [SKColor(red: 0.04, green: 0.07, blue: 0.16, alpha: 1), SKColor(red: 0.03, green: 0.20, blue: 0.12, alpha: 1), SKColor(red: 0.28, green: 0.13, blue: 0.03, alpha: 1), SKColor(red: 0.08, green: 0.22, blue: 0.32, alpha: 1), SKColor(red: 0.12, green: 0.05, blue: 0.25, alpha: 1)][min(level - 1, 4)] }

    func begin(level: Int, progress: PlayerProgress, infinite: Bool = false) {
        self.level = level; isInfinite = infinite; platformIndex = infinite ? progress.infinitePlatform : progress.platform; score = infinite ? progress.infiniteScore : progress.score; lives = max(progress.lives, 1)
        state = .ready; velocity = .zero; glideEnergy = 1; elapsed = 0; lastUpdate = 0; collectedFruitPlatforms.removeAll(); pendingFruit = nil; rescueFromFall = false; zeroLifeFallCount = 0
        removeAllChildren(); platforms.removeAll(); motions.removeAll(); fruits.removeAll(); backgroundColor = themeColor
        setupBackdrop(); setupPlayer(); buildCourse(); placePlayer(on: platformIndex); reportHUD()
    }

    private func setupPlayer() {
        player.removeAllChildren(); player.removeFromParent(); let character = ProgressStore.shared.load().selectedCharacter % 4; player.fillColor = [SKColor(red: 1, green: 0.53, blue: 0.13, alpha: 1), SKColor(red: 0.05, green: 0.55, blue: 0.95, alpha: 1), SKColor(red: 1, green: 0.78, blue: 0.10, alpha: 1), SKColor(red: 0.23, green: 0.76, blue: 0.39, alpha: 1)][character]; player.strokeColor = .white.withAlphaComponent(0.60); player.lineWidth = 1.5; player.zPosition = 10
        let highlight = SKShapeNode(rectOf: CGSize(width: 18, height: 4), cornerRadius: 2); highlight.fillColor = .white.withAlphaComponent(0.23); highlight.strokeColor = .clear; highlight.position = CGPoint(x: -2, y: 10); player.addChild(highlight)
        for (eye, pupil, x) in [(leftEye, leftPupil, -8), (rightEye, rightPupil, 8)] { eye.fillColor = .white; eye.strokeColor = .clear; eye.position = CGPoint(x: x, y: 3); pupil.fillColor = SKColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 1); pupil.strokeColor = .clear; eye.addChild(pupil); player.addChild(eye) }
        for brow in [leftBrow, rightBrow] { brow.strokeColor = SKColor(red: 0.34, green: 0.12, blue: 0.03, alpha: 1); brow.lineWidth = 2.6; brow.lineCap = .round; brow.isHidden = true; player.addChild(brow) }
        mouth.strokeColor = SKColor(red: 0.45, green: 0.18, blue: 0.06, alpha: 1); mouth.fillColor = .clear; mouth.lineWidth = 2.4; mouth.lineCap = .round; player.addChild(mouth); playerExpression = .landing; setPlayerExpression(.neutral); addChild(player)
        preview.strokeColor = .white.withAlphaComponent(0.72); preview.lineWidth = 2; preview.zPosition = 4; preview.isHidden = true; addChild(preview)
        landingMarker.zPosition = 5; landingMarker.lineWidth = 3; landingMarker.fillColor = .clear; landingMarker.isHidden = true; addChild(landingMarker)
    }

    private func setupBackdrop() {
        let moon = SKShapeNode(circleOfRadius: 28); moon.fillColor = .systemYellow; moon.strokeColor = .clear; moon.position = CGPoint(x: size.width - 58, y: size.height - 105); moon.zPosition = -20; addChild(moon)
        for index in 0..<30 { let star = SKShapeNode(circleOfRadius: index.isMultiple(of: 4) ? 1.4 : 0.8); star.fillColor = .white.withAlphaComponent(0.7); star.strokeColor = .clear; star.position = CGPoint(x: CGFloat((index * 47) % max(Int(size.width), 1)), y: CGFloat(90 + (index * 83) % max(Int(size.height - 120), 1))); star.zPosition = -21; addChild(star) }
    }

    private func buildCourse() {
        let count = isInfinite ? max(platformIndex + 115, 150) : 100; var x = size.width * 0.16; var y = size.height * 0.27; var previousWidth: CGFloat = 132
        for index in 0...count {
            let difficulty = min(1, CGFloat(index) / 87 * 1.15); let width = index == count && !isInfinite ? max(140, size.width * 0.38) : 134 - difficulty * 54
            if index > 0 { let gap = CGFloat.random(in: 86 + difficulty * 86...110 + difficulty * 120); x += previousWidth / 2 + gap + width / 2; y = min(max(size.height * 0.34, y + CGFloat.random(in: -(20 + difficulty * 32)...20 + difficulty * 32)), size.height * 0.80) }
            let platform = SKSpriteNode(color: index == count && !isInfinite ? .systemYellow : (index == 0 ? .systemTeal : .systemIndigo), size: CGSize(width: width, height: 16)); platform.position = CGPoint(x: x, y: y); platform.name = "platform-\(index)"; platform.zPosition = 2; addChild(platform); platforms.append(platform)
            if index > 0 && index < count && index.isMultiple(of: 5) { addFruit(near: platform, index: index) }
            if index > 12 && index.isMultiple(of: 9) { motions[index] = Motion(axis: index.isMultiple(of: 2) ? CGVector(dx: 1, dy: 0) : CGVector(dx: 0, dy: 1), amplitude: 20 + difficulty * 32, period: 3.6, origin: platform.position) }
            previousWidth = width
        }
    }

    private func addFruit(near platform: SKSpriteNode, index: Int) {
        let roll = Int.random(in: 0...99); let kind: FruitKind = roll < 55 ? .apple : roll < 68 ? .banana : roll < 81 ? .grapes : roll < 92 ? .lemon : .broccoli
        let node = SKLabelNode(text: kind.emoji); node.fontSize = 25; node.zPosition = 6; node.position = CGPoint(x: platform.position.x, y: platform.position.y + 28); addChild(node); fruits.append(Fruit(kind: kind, platformIndex: index, node: node))
    }

    private func placePlayer(on index: Int) { guard platforms.indices.contains(index) else { return }; let platform = platforms[index]; player.position = CGPoint(x: platform.position.x - platform.size.width * 0.18, y: platform.position.y + platform.size.height / 2 + player.frame.height / 2); previousPosition = player.position; standingPlatform = index }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { guard state != .paused && state != .finished else { return }; touchHeld = true; if state == .ready { state = .charging; chargingSince = CACurrentMediaTime(); power = 0; preview.isHidden = false; landingMarker.isHidden = false } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { touchHeld = false; releaseJump() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchHeld = false; releaseJump() }
    private func releaseJump() { guard state == .charging else { return }; let appliedPower = max(minimumPower, power); velocity = CGVector(dx: appliedPower * 700, dy: -(340 + appliedPower * 620)); launchPlatform = platformIndex; standingPlatform = nil; state = .jumping; preview.isHidden = true; landingMarker.isHidden = true; UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    override func update(_ currentTime: TimeInterval) {
        guard state != .paused && state != .finished else { return }; let delta = lastUpdate == 0 ? 0 : min(CGFloat(currentTime - lastUpdate), 1 / 30); lastUpdate = currentTime; elapsed += TimeInterval(delta)
        updatePlatforms(); updateFruitPositions()
        if state == .charging { power = min(CGFloat((currentTime - chargingSince) / chargeDuration), 1); drawTrajectory(for: max(minimumPower, power)) }
        if state == .jumping { updateJump(delta: delta) }
        updatePlayerAppearance()
        updateCamera(delta: delta); reportHUD()
    }

    private func updatePlatforms() {
        for (index, motion) in motions { guard platforms.indices.contains(index) else { continue }; let platform = platforms[index]; let old = platform.position; let phase = CGFloat(sin(elapsed / motion.period * .pi * 2)); platform.position = CGPoint(x: motion.origin.x + motion.axis.dx * motion.amplitude * phase, y: motion.origin.y + motion.axis.dy * motion.amplitude * phase); if standingPlatform == index && state == .ready { player.position.x += platform.position.x - old.x; player.position.y += platform.position.y - old.y } }
    }
    private func updateFruitPositions() { for fruit in fruits where !collectedFruitPlatforms.contains(fruit.platformIndex) && platforms.indices.contains(fruit.platformIndex) { let platform = platforms[fruit.platformIndex]; fruit.node.position = CGPoint(x: platform.position.x, y: platform.position.y + 28) } }

    private func updateJump(delta: CGFloat) {
        previousPosition = player.position; let gliding = velocity.dy > 30 && glideEnergy > 0 && (touchHeld || calibratedTilt.dy > 0.18); let appliedGravity = gliding ? gravity * 0.30 : gravity
        if gliding { velocity.dx *= exp(-1.75 * delta); glideEnergy = max(0, glideEnergy - delta / glideDuration) }
        velocity.dy = min(velocity.dy + appliedGravity * delta, gliding ? 360 : .greatestFiniteMagnitude); velocity.dx += max(-1, min(1, calibratedTilt.dx)) * 280 * delta
        player.position.x += velocity.dx * delta; player.position.y -= velocity.dy * delta; player.xScale = velocity.dy < 0 ? 0.90 : 1.06; player.yScale = velocity.dy < 0 ? 1.12 : 0.92
        if tryLand() { return }; collectTouchedFruit(); if player.position.y < -120 { handleFall() }
    }

    private func tryLand() -> Bool {
        guard velocity.dy > 0 else { return false }; let index = platformIndex + 1; guard platforms.indices.contains(index) else { return false }; let platform = platforms[index]; let halfHeight = player.frame.height / 2; let top = platform.position.y + platform.size.height / 2
        guard previousPosition.y - halfHeight >= top, player.position.y - halfHeight <= top else { return false }; let halfWidth = player.frame.width / 2
        guard player.position.x + halfWidth >= platform.position.x - platform.size.width / 2, player.position.x - halfWidth <= platform.position.x + platform.size.width / 2 else { return false }; land(on: index); return true
    }
    private func land(on index: Int) {
        let platform = platforms[index]; player.setScale(1); player.position.y = platform.position.y + platform.size.height / 2 + player.frame.height / 2; velocity = .zero; state = .ready; landingExpressionEndsAt = elapsed + 0.18; standingPlatform = index; platformIndex = index; glideEnergy = 1; score += 1
        if abs(player.position.x - platform.position.x) <= platform.size.width * 0.18 { score += 1; UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }; collectFruit(on: index)
        if !isInfinite && index >= 100 { state = .finished; gameDelegate?.gameSceneDidFinishLevel(self) } else if isInfinite && index > 0 && index.isMultiple(of: 100) { state = .paused; gameDelegate?.gameScene(self, requestExam: .broccoli) }
    }
    private func collectTouchedFruit() { for fruit in fruits where !collectedFruitPlatforms.contains(fruit.platformIndex) && player.frame.insetBy(dx: -8, dy: -8).contains(fruit.node.position) { collect(fruit) } }
    private func collectFruit(on index: Int) { for fruit in fruits where fruit.platformIndex == index && !collectedFruitPlatforms.contains(index) { collect(fruit) } }
    private func collect(_ fruit: Fruit) { collectedFruitPlatforms.insert(fruit.platformIndex); fruit.node.removeFromParent(); pendingFruit = fruit.kind; switch fruit.kind { case .apple: lives += 1; pendingFruit = nil; case .banana, .grapes, .lemon: state = .paused; gameDelegate?.gameScene(self, requestExam: .rescue); case .broccoli: state = .paused; gameDelegate?.gameScene(self, requestExam: .broccoli) } }
    private func handleFall() {
        velocity = .zero; player.setScale(1); glideEnergy = 1
        if lives > 0 {
            lives -= 1; platformIndex = launchPlatform; placePlayer(on: launchPlatform); state = .ready
            return
        }
        zeroLifeFallCount += 1
        guard zeroLifeFallCount < 4 else {
            state = .finished; gameDelegate?.gameSceneDidEndGame(self); return
        }
        rescueFromFall = true; state = .paused; pendingFruit = nil
        gameDelegate?.gameScene(self, requestExam: .fallRescueForAttempt(zeroLifeFallCount))
    }

    func resumeAfterExam(success: Bool, kind: ExamKind) {
        if rescueFromFall {
            rescueFromFall = false
            guard success else { state = .finished; gameDelegate?.gameSceneDidEndGame(self); return }
            platformIndex = launchPlatform; placePlayer(on: launchPlatform); velocity = .zero; glideEnergy = 1; state = .ready; reportHUD(); return
        }
        if success { if pendingFruit == .banana { lives += 1 }; if pendingFruit == .grapes { platformIndex = min(platformIndex + 3, platforms.count - 1); score += 3; placePlayer(on: platformIndex) }; pendingFruit = nil; velocity = .zero; glideEnergy = 1; state = .ready } else if pendingFruit == .grapes { platformIndex = max(0, platformIndex - 5); pendingFruit = nil; placePlayer(on: platformIndex); state = .ready } else if kind == .broccoli || kind == .final || pendingFruit == .lemon { pendingFruit = nil; state = .finished; gameDelegate?.gameSceneDidEndGame(self) } else { pendingFruit = nil; state = .ready }; reportHUD()
    }
    func setPaused(_ paused: Bool) { if paused && state != .finished { state = .paused; touchHeld = false } else if !paused && state == .paused && pendingFruit == nil { state = .ready; lastUpdate = 0 } }

    private func updatePlayerAppearance() {
        switch state {
        case .charging:
            let amount = power; player.xScale = 1 + amount * 0.14; player.yScale = 1 - amount * 0.16; setPlayerExpression(.charging)
        case .jumping where velocity.dy < 0:
            player.xScale = 0.90; player.yScale = 1.12; setPlayerExpression(.ascending)
        case .jumping:
            player.xScale = 1.06; player.yScale = 0.92; setPlayerExpression(.falling)
        case .ready where elapsed < landingExpressionEndsAt:
            player.xScale = 1.13; player.yScale = 0.82; setPlayerExpression(.landing)
        default:
            player.setScale(1); setPlayerExpression(.neutral)
        }
    }

    private func setPlayerExpression(_ expression: PlayerExpression) {
        guard playerExpression != expression else { return }
        playerExpression = expression
        [leftEye, rightEye].forEach { $0.setScale(1); $0.fillColor = .white }
        [leftPupil, rightPupil].forEach { $0.isHidden = false; $0.position = CGPoint(x: 1, y: -0.5) }
        [leftBrow, rightBrow].forEach { $0.isHidden = true }
        let smile = CGMutablePath(); smile.move(to: CGPoint(x: -6, y: -7)); smile.addQuadCurve(to: CGPoint(x: 6, y: -7), control: CGPoint(x: 0, y: -12))
        mouth.path = smile; mouth.fillColor = .clear; mouth.strokeColor = SKColor(red: 0.45, green: 0.18, blue: 0.06, alpha: 1)
        switch expression {
        case .charging:
            let leftPath = CGMutablePath(); leftPath.move(to: CGPoint(x: -12, y: 9)); leftPath.addLine(to: CGPoint(x: -4, y: 7)); leftBrow.path = leftPath
            let rightPath = CGMutablePath(); rightPath.move(to: CGPoint(x: 12, y: 9)); rightPath.addLine(to: CGPoint(x: 4, y: 7)); rightBrow.path = rightPath
            leftBrow.isHidden = false; rightBrow.isHidden = false
            let focusedMouth = CGMutablePath(); focusedMouth.move(to: CGPoint(x: -4, y: -8)); focusedMouth.addLine(to: CGPoint(x: 0, y: -10)); focusedMouth.addLine(to: CGPoint(x: 4, y: -8)); mouth.path = focusedMouth
        case .ascending:
            leftPupil.position = CGPoint(x: 1.2, y: 0.2); rightPupil.position = CGPoint(x: 1.2, y: 0.2)
        case .falling:
            leftEye.yScale = 1.14; rightEye.yScale = 1.14; leftPupil.position = CGPoint(x: 0, y: -1); rightPupil.position = CGPoint(x: 0, y: -1)
            mouth.path = CGPath(ellipseIn: CGRect(x: -3.5, y: -11, width: 7, height: 7), transform: nil); mouth.fillColor = SKColor(red: 0.45, green: 0.18, blue: 0.06, alpha: 1); mouth.strokeColor = .clear
        case .landing:
            leftEye.yScale = 0.28; rightEye.yScale = 0.28; leftPupil.isHidden = true; rightPupil.isHidden = true
            let happyMouth = CGMutablePath(); happyMouth.move(to: CGPoint(x: -6, y: -7)); happyMouth.addQuadCurve(to: CGPoint(x: 6, y: -7), control: CGPoint(x: 0, y: -13)); mouth.path = happyMouth
        case .neutral: break
        }
    }

    private func drawTrajectory(for power: CGFloat) {
        var point = player.position; var simulatedVelocity = CGVector(dx: power * 700, dy: -(340 + power * 620)); let path = CGMutablePath(); var landing: CGPoint?; let target = platforms.indices.contains(platformIndex + 1) ? platforms[platformIndex + 1] : nil
        for step in 0..<40 { simulatedVelocity.dy += gravity * 0.045; let previous = point; point.x += simulatedVelocity.dx * 0.045; point.y -= simulatedVelocity.dy * 0.045; if step.isMultiple(of: 2) { path.move(to: previous); path.addLine(to: point) }; if let target, simulatedVelocity.dy > 0, previous.y - player.frame.height / 2 >= target.position.y + target.size.height / 2, point.y - player.frame.height / 2 <= target.position.y + target.size.height / 2 { landing = point; break } }
        preview.path = path; landingMarker.position = landing ?? point; let viable = landing.map { point in guard let target else { return false }; return point.x + player.frame.width / 2 >= target.position.x - target.size.width / 2 && point.x - player.frame.width / 2 <= target.position.x + target.size.width / 2 } ?? false; landingMarker.strokeColor = viable ? .systemGreen : .systemRed
    }
    private func updateCamera(delta: CGFloat) { guard player.position.x > size.width * 0.46 else { return }; let shift = (player.position.x - size.width * 0.34) * min(1, delta * 10); player.position.x -= shift; previousPosition.x -= shift; for platform in platforms { platform.position.x -= shift }; for (index, motion) in motions { motions[index] = Motion(axis: motion.axis, amplitude: motion.amplitude, period: motion.period, origin: CGPoint(x: motion.origin.x - shift, y: motion.origin.y)) }; for fruit in fruits { fruit.node.position.x -= shift }; preview.position.x -= shift; landingMarker.position.x -= shift }
    private var glideDuration: CGFloat { [3, 2.5, 2, 1.5, 1][min(level - 1, 4)] }
    func snapshot(into progress: inout PlayerProgress) { if isInfinite { progress.infinitePlatform = platformIndex; progress.infiniteScore = score } else { progress.currentLevel = level; progress.platform = platformIndex; progress.score = score; progress.lives = lives } }
    private func reportHUD() { gameDelegate?.gameScene(self, didUpdateHUD: score, platform: platformIndex, lives: lives, level: level, energy: state == .charging ? power : glideEnergy) }
    private func startMotion() { guard motionManager.isDeviceMotionAvailable else { return }; motionManager.deviceMotionUpdateInterval = 1 / 60; motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in guard let self, let gravity = motion?.gravity else { return }; if self.motionBaseline == nil { self.motionBaseline = gravity }; guard let baseline = self.motionBaseline else { return }; let x = gravity.x - baseline.x; let y = gravity.y - baseline.y; self.calibratedTilt = CGVector(dx: abs(x) > 0.07 ? max(-0.7, min(0.7, x)) : 0, dy: abs(y) > 0.12 ? max(-0.7, min(0.7, y)) : 0) } }
    deinit { motionManager.stopDeviceMotionUpdates() }
}
