import SpriteKit
import CoreMotion
import GameKit

protocol GameSceneDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didUpdateHUD score: Int, platform: Int, lives: Int, level: Int, energy: CGFloat)
    func gameScene(_ scene: GameScene, requestExam kind: ExamKind)
    func gameSceneDidFinishLevel(_ scene: GameScene)
    func gameSceneDidEndGame(_ scene: GameScene)
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var gameDelegate: GameSceneDelegate?
    var level = 1
    var platformIndex = 0
    var score = 0
    var lives = 1
    var isInfinite = false
    private let player = SKShapeNode(rectOf: CGSize(width: 38, height: 38), cornerRadius: 8)
    private var platforms: [SKSpriteNode] = []
    private var fruitNodes = [SKNode: FruitKind]()
    private var isCharging = false
    private var chargeStart: TimeInterval = 0
    private var jumpCharge: CGFloat = 0
    private var isGliding = false
    private var glideEnergy: CGFloat = 1
    private var lastUpdate: TimeInterval = 0
    private let motionManager = CMMotionManager()
    private var hasStarted = false
    private var movingBackdropNodes: [SKNode] = []
    private(set) var pendingFruit: FruitKind?
    private let playerCategory: UInt32 = 1
    private let platformCategory: UInt32 = 2
    private let fruitCategory: UInt32 = 4

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -6.6)
        physicsWorld.contactDelegate = self
        backgroundColor = themeColor
        setupPlayer()
        startMotion()
    }

    var themeColor: SKColor {
        [SKColor(red: 0.04, green: 0.07, blue: 0.16, alpha: 1), SKColor(red: 0.03, green: 0.20, blue: 0.12, alpha: 1), SKColor(red: 0.28, green: 0.13, blue: 0.03, alpha: 1), SKColor(red: 0.08, green: 0.22, blue: 0.32, alpha: 1), SKColor(red: 0.12, green: 0.05, blue: 0.25, alpha: 1)][min(level - 1, 4)]
    }

    func begin(level: Int, progress: PlayerProgress, infinite: Bool = false) {
        self.level = level; isInfinite = infinite; platformIndex = infinite ? progress.infinitePlatform : progress.platform; score = infinite ? progress.infiniteScore : progress.score; lives = max(progress.lives, 1)
        removeAllChildren(); platforms.removeAll(); fruitNodes.removeAll(); movingBackdropNodes.removeAll(); backgroundColor = themeColor; setupBackdrop(); setupPlayer(); buildCourse(); hasStarted = true; reportHUD()
    }

    private func setupPlayer() {
        player.removeAllChildren(); player.removeFromParent(); let selectedCharacter = ProgressStore.shared.load().selectedCharacter % 4; player.fillColor = [.orange, .systemBlue, .systemYellow, .systemGreen][selectedCharacter]; player.strokeColor = .white; player.position = CGPoint(x: size.width / 2, y: 120); player.name = "player"; if selectedCharacter == 0 { let eyeStyle: (CGFloat) -> SKShapeNode = { x in let eye = SKShapeNode(circleOfRadius: 6); eye.fillColor = .white; eye.strokeColor = .clear; eye.position = CGPoint(x: x, y: 5); let pupil = SKShapeNode(circleOfRadius: 2.5); pupil.fillColor = .black; pupil.strokeColor = .clear; pupil.position = CGPoint(x: 1, y: 0); eye.addChild(pupil); return eye }; player.addChild(eyeStyle(-9)); player.addChild(eyeStyle(9)); let mouth = SKShapeNode(rectOf: CGSize(width: 15, height: 3), cornerRadius: 1.5); mouth.fillColor = .black; mouth.strokeColor = .clear; mouth.position = CGPoint(x: 0, y: -9); player.addChild(mouth) }; player.physicsBody = SKPhysicsBody(rectangleOf: player.frame.size); player.physicsBody?.allowsRotation = false; player.physicsBody?.restitution = 0; player.physicsBody?.categoryBitMask = playerCategory; player.physicsBody?.contactTestBitMask = platformCategory | fruitCategory; player.physicsBody?.collisionBitMask = platformCategory; addChild(player)
    }

    private func setupBackdrop() { let moon = SKShapeNode(circleOfRadius: 28); moon.fillColor = SKColor(red: 1, green: 0.98, blue: 0.72, alpha: 1); moon.strokeColor = .clear; moon.position = CGPoint(x: size.width - 58, y: size.height - 105); moon.zPosition = -20; addChild(moon); for index in 0..<38 { let star = SKShapeNode(circleOfRadius: index % 4 == 0 ? 1.4 : 0.8); star.fillColor = .white.withAlphaComponent(0.7); star.strokeColor = .clear; star.position = CGPoint(x: CGFloat((index * 47) % max(Int(size.width), 1)), y: CGFloat(90 + (index * 83) % max(Int(size.height - 120), 1))); star.zPosition = -21; addChild(star) }; for index in 0..<5 { let cloud = SKShapeNode(ellipseOf: CGSize(width: 94, height: 28)); cloud.fillColor = SKColor(red: 0.34, green: 0.40, blue: 0.55, alpha: 0.55); cloud.strokeColor = .clear; cloud.position = CGPoint(x: CGFloat(index) * size.width / 4 + 20, y: size.height * (0.42 + CGFloat(index % 3) * 0.14)); cloud.zPosition = -19; addChild(cloud); movingBackdropNodes.append(cloud) } }

    private func buildCourse() {
        let platformCount = isInfinite ? max(platformIndex + 115, 150) : 100
        var vertical: CGFloat = 75
        var horizontal = size.width / 2
        for index in 0...platformCount {
            let difficulty = CGFloat(level - 1) * 0.12 + CGFloat(index) / 850
            let width = max(58, 118 - difficulty * 74)
            if index > 0 { vertical += 86 + CGFloat.random(in: 0...28); horizontal = min(max(45 + width / 2, horizontal + CGFloat.random(in: -145...145)), size.width - 45 - width / 2) }
            let platform = SKSpriteNode(color: index == 0 ? .systemTeal : .systemIndigo, size: CGSize(width: width, height: 16)); platform.position = CGPoint(x: horizontal, y: vertical); platform.name = "platform-\(index)"; platform.physicsBody = SKPhysicsBody(rectangleOf: platform.size); platform.physicsBody?.isDynamic = false; platform.physicsBody?.categoryBitMask = platformCategory; addChild(platform); platforms.append(platform)
            if index > 0 && index % 5 == 0 { addFruit(near: platform, index: index) }
            if index > 12 && index % 9 == 0 { let distance = 32 + difficulty * 50; platform.run(.repeatForever(.sequence([.moveBy(x: distance, y: index % 2 == 0 ? 0 : distance / 2, duration: 1.8), .moveBy(x: -distance, y: index % 2 == 0 ? 0 : -distance / 2, duration: 1.8)]))) }
        }
    }

    private func addFruit(near platform: SKSpriteNode, index: Int) {
        let roll = Int.random(in: 0...99); let kind: FruitKind = roll < 55 ? .apple : roll < 68 ? .banana : roll < 81 ? .grapes : roll < 92 ? .lemon : .broccoli
        let label = SKLabelNode(text: kind.emoji); label.fontSize = 25; label.position = CGPoint(x: platform.position.x, y: platform.position.y + 28); label.name = "fruit"; label.physicsBody = SKPhysicsBody(circleOfRadius: 13); label.physicsBody?.isDynamic = false; label.physicsBody?.categoryBitMask = fruitCategory; label.physicsBody?.contactTestBitMask = playerCategory; addChild(label); fruitNodes[label] = kind
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { guard hasStarted else { return }; if player.physicsBody?.velocity.dy ?? 0 < 5 { isCharging = true; jumpCharge = 0; chargeStart = CACurrentMediaTime() } else { isGliding = true } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { releaseJumpIfNeeded(); isGliding = false }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { releaseJumpIfNeeded(); isGliding = false }
    private func releaseJumpIfNeeded() { guard isCharging else { return }; jumpCharge = min(CGFloat(CACurrentMediaTime() - chargeStart) / 1.25, 1); player.physicsBody?.velocity = CGVector(dx: 0, dy: 300 + jumpCharge * 560); isCharging = false; jumpCharge = 0; UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    override func update(_ currentTime: TimeInterval) {
        guard hasStarted else { return }; let delta = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.05); lastUpdate = currentTime
        if isCharging { jumpCharge = min(CGFloat(currentTime - chargeStart) / 1.25, 1) }
        for node in movingBackdropNodes { node.position.x -= CGFloat(delta) * 18; if node.position.x < -60 { node.position.x = size.width + 60 } }
        if isGliding && glideEnergy > 0 { player.physicsBody?.velocity.dy = max(player.physicsBody?.velocity.dy ?? 0, -85); glideEnergy = max(0, glideEnergy - CGFloat(delta) / glideDuration) }
        if player.physicsBody?.velocity.dy ?? 0 <= 0, let standing = closestPlatformBelow(), abs(player.position.y - standing.position.y) < 45 { glideEnergy = min(1, glideEnergy + CGFloat(delta) * 1.8) }
        if player.position.y > size.height * 0.58 { let shift = player.position.y - size.height * 0.45; player.position.y -= shift; for platform in platforms { platform.position.y -= shift }; for node in fruitNodes.keys { node.position.y -= shift } }
        if player.position.y < -90 { handleFall() }; reportHUD()
    }

    private var glideDuration: CGFloat { [3, 2.5, 2, 1.5, 1][min(level - 1, 4)] }
    private func closestPlatformBelow() -> SKSpriteNode? { platforms.filter { $0.position.y <= player.position.y }.max { $0.position.y < $1.position.y } }
    func didBegin(_ contact: SKPhysicsContact) {
        let first = contact.bodyA; let second = contact.bodyB
        if (first.categoryBitMask | second.categoryBitMask) == (playerCategory | fruitCategory) { let node = first.categoryBitMask == fruitCategory ? first.node : second.node; if let node, let fruit = fruitNodes.removeValue(forKey: node) { node.removeFromParent(); collect(fruit) } }
        if (first.categoryBitMask | second.categoryBitMask) == (playerCategory | platformCategory), player.physicsBody?.velocity.dy ?? 0 <= 0 { guard let platform = first.categoryBitMask == platformCategory ? first.node : second.node, let name = platform.name, let index = Int(name.replacingOccurrences(of: "platform-", with: "")) else { return }; if index > platformIndex { score += 1; if abs(player.position.x - platform.position.x) < 12 { score += 1 }; platformIndex = index; if !isInfinite && platformIndex >= 100 { hasStarted = false; gameDelegate?.gameSceneDidFinishLevel(self) } else if isInfinite && platformIndex > 0 && platformIndex % 100 == 0 { hasStarted = false; gameDelegate?.gameScene(self, requestExam: .broccoli) } } }
    }

    private func collect(_ fruit: FruitKind) { switch fruit { case .apple: lives += 1; case .banana, .grapes, .lemon: pendingFruit = fruit; hasStarted = false; gameDelegate?.gameScene(self, requestExam: .rescue); case .broccoli: pendingFruit = fruit; hasStarted = false; gameDelegate?.gameScene(self, requestExam: .broccoli) }; reportHUD() }
    private func handleFall() { guard hasStarted else { return }; lives -= 1; if lives >= 0 { player.position = closestPlatformBelow()?.position ?? CGPoint(x: size.width / 2, y: 120); player.position.y += 45; player.physicsBody?.velocity = .zero } else { hasStarted = false; gameDelegate?.gameScene(self, requestExam: .rescue) }; reportHUD() }
    func resumeAfterExam(success: Bool, kind: ExamKind) { if success { if pendingFruit == .banana { lives += 1 }; if pendingFruit == .grapes { platformIndex += 3; score += 3 }; lives = max(0, lives); pendingFruit = nil; hasStarted = true; player.position = closestPlatformBelow()?.position ?? player.position; player.position.y += 45; player.physicsBody?.velocity = .zero } else { if pendingFruit == .grapes { platformIndex = max(0, platformIndex - 5); pendingFruit = nil; hasStarted = true } else if kind == .broccoli || kind == .final || lives < 0 || pendingFruit == .lemon { pendingFruit = nil; gameDelegate?.gameSceneDidEndGame(self) } }; reportHUD() }
    func snapshot(into progress: inout PlayerProgress) { if isInfinite { progress.infinitePlatform = platformIndex; progress.infiniteScore = score } else { progress.currentLevel = level; progress.platform = platformIndex; progress.score = score; progress.lives = lives } }
    private func reportHUD() { gameDelegate?.gameScene(self, didUpdateHUD: score, platform: platformIndex, lives: lives, level: level, energy: isCharging ? jumpCharge : glideEnergy) }
    private func startMotion() { guard motionManager.isDeviceMotionAvailable else { return }; motionManager.deviceMotionUpdateInterval = 1 / 60; motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in guard let self, let gravity = motion?.gravity else { return }; self.player.physicsBody?.applyForce(CGVector(dx: gravity.x * 32, dy: 0)); if gravity.y > 0.45 { self.isGliding = true } } }
    deinit { motionManager.stopDeviceMotionUpdates() }
}
