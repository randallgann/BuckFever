import SpriteKit
import UIKit

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none:    UInt32 = 0
    static let arrow:   UInt32 = 0b0001
    static let deer:    UInt32 = 0b0010
    static let ground:  UInt32 = 0b0100
}

// MARK: - Deer Data
struct DeerInfo {
    let rackSize: RackSize
    let speed: CGFloat
    let direction: DeerDirection

    enum RackSize: CaseIterable {
        case spike, sixPoint, eightPoint, trophy

        var points: Int {
            switch self {
            case .spike: return 10
            case .sixPoint: return 25
            case .eightPoint: return 50
            case .trophy: return 100
            }
        }

        var bodySize: CGSize {
            switch self {
            case .spike:      return CGSize(width: 50, height: 30)
            case .sixPoint:   return CGSize(width: 65, height: 39)
            case .eightPoint: return CGSize(width: 80, height: 48)
            case .trophy:     return CGSize(width: 95, height: 57)
            }
        }

        var color: UIColor {
            switch self {
            case .spike:      return UIColor(red: 0.55, green: 0.40, blue: 0.25, alpha: 1)
            case .sixPoint:   return UIColor(red: 0.60, green: 0.42, blue: 0.25, alpha: 1)
            case .eightPoint: return UIColor(red: 0.50, green: 0.35, blue: 0.20, alpha: 1)
            case .trophy:     return UIColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1)
            }
        }

        var antlerPoints: Int {
            switch self {
            case .spike: return 2
            case .sixPoint: return 6
            case .eightPoint: return 8
            case .trophy: return 10
            }
        }

        static func random() -> RackSize {
            let roll = Int.random(in: 0..<100)
            switch roll {
            case 0..<40:  return .spike
            case 40..<75: return .sixPoint
            case 75..<95: return .eightPoint
            default:      return .trophy
            }
        }
    }

    enum DeerDirection {
        case leftToRight, rightToLeft
    }
}

// MARK: - HuntingScene

class HuntingScene: SKScene, SKPhysicsContactDelegate {

    weak var gameState: GameState?

    // Nodes
    private var bowNode: SKNode!
    private var bowBody: SKShapeNode!
    private var bowString: SKShapeNode!
    private var nockPoint: SKShapeNode!         // Where the arrow sits on the string
    private var arrowNode: SKNode?              // Active arrow being aimed
    private var trajectoryDots: [SKShapeNode] = []

    // Aiming state
    private var isDrawing = false
    private var drawAnchor: CGPoint = .zero     // Where the touch started
    private var drawVector: CGVector = .zero    // Current pull-back vector
    private var drawPower: CGFloat = 0          // 0.0–1.0 normalized

    // Haptics
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let releaseHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private var lastHapticThreshold: CGFloat = 0

    // Timers
    private var deerSpawnAccumulator: TimeInterval = 0
    private var countdownAccumulator: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Scene Setup

    private var didSetup = false

    override func didMove(to view: SKView) {
        print("[HuntingScene] didMove called, didSetup=\(didSetup)")
        guard !didSetup else { return }
        didSetup = true
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: PhysicsConstants.gravity)
        physicsWorld.contactDelegate = self

        setupBackground()
        setupGround()
        setupBow()
        nockArrow()

        lightHaptic.prepare()
        mediumHaptic.prepare()
        heavyHaptic.prepare()
        releaseHaptic.prepare()
    }

    // MARK: - Background

    private func setupBackground() {
        let bg = SKNode()

        // Sky gradient
        let skyColors = [
            UIColor(red: 0.85, green: 0.65, blue: 0.45, alpha: 1),
            UIColor(red: 0.95, green: 0.80, blue: 0.55, alpha: 1)
        ]
        let skyTexture = createGradientTexture(size: size, colors: skyColors)
        let skySprite = SKSpriteNode(texture: skyTexture, size: size)
        skySprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        skySprite.zPosition = -10
        bg.addChild(skySprite)

        // Tree line
        let treeLineY = size.height * 0.57
        let treeLineHeight: CGFloat = 80
        for x in stride(from: CGFloat(0), through: size.width, by: 30) {
            let h = 20 + (sin(x * 0.043) + 1) * 25
            let tree = SKShapeNode(path: trianglePath(width: 30, height: h))
            tree.fillColor = UIColor(red: 0.10, green: 0.18, blue: 0.10, alpha: 1)
            tree.strokeColor = .clear
            tree.position = CGPoint(x: x + 15, y: treeLineY)
            tree.zPosition = -5
            bg.addChild(tree)
        }

        // Clearing (grass)
        let clearingHeight = size.height * 0.55
        let clearing = SKSpriteNode(color: UIColor(red: 0.40, green: 0.45, blue: 0.22, alpha: 1),
                                     size: CGSize(width: size.width, height: clearingHeight))
        clearing.position = CGPoint(x: size.width / 2, y: clearingHeight / 2)
        clearing.zPosition = -8
        bg.addChild(clearing)

        // Foreground brush
        let brush = SKSpriteNode(color: UIColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1),
                                  size: CGSize(width: size.width, height: 60))
        brush.position = CGPoint(x: size.width / 2, y: 30)
        brush.zPosition = 5
        bg.addChild(brush)

        addChild(bg)
    }

    private func trianglePath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.closeSubpath()
        return path
    }

    private func createGradientTexture(size: CGSize, colors: [UIColor]) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cgColors = colors.map { $0.cgColor } as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: cgColors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient,
                                             start: CGPoint(x: 0, y: 0),
                                             end: CGPoint(x: 0, y: size.height),
                                             options: [])
        }
        return SKTexture(image: image)
    }

    // MARK: - Ground

    private func setupGround() {
        let ground = SKNode()
        ground.position = CGPoint(x: size.width / 2, y: 55)
        ground.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2, height: 10))
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = PhysicsCategory.ground
        ground.physicsBody?.contactTestBitMask = PhysicsCategory.arrow
        addChild(ground)
    }

    // MARK: - Bow

    private func setupBow() {
        let bowX = size.width / 2
        let bowY = PhysicsConstants.bowYOffset

        bowNode = SKNode()
        bowNode.position = CGPoint(x: bowX, y: bowY)
        bowNode.zPosition = 10

        // Bow limbs (curved arc)
        let bowPath = CGMutablePath()
        bowPath.addArc(center: CGPoint(x: 0, y: 0),
                       radius: 50,
                       startAngle: .pi * 0.3,
                       endAngle: .pi * 0.7,
                       clockwise: true)
        bowBody = SKShapeNode(path: bowPath)
        bowBody.strokeColor = UIColor(red: 0.40, green: 0.25, blue: 0.12, alpha: 1)
        bowBody.lineWidth = 5
        bowBody.fillColor = .clear
        bowNode.addChild(bowBody)

        // Bow string (straight line from tip to tip, will bend during draw)
        updateBowString(pullBack: 0)

        // Nock point (invisible touch target)
        nockPoint = SKShapeNode(circleOfRadius: 30)
        nockPoint.fillColor = .clear
        nockPoint.strokeColor = .clear
        nockPoint.position = CGPoint(x: 0, y: 0)
        bowNode.addChild(nockPoint)

        addChild(bowNode)
    }

    private func updateBowString(pullBack: CGFloat) {
        bowString?.removeFromParent()

        let stringPath = CGMutablePath()
        // String endpoints (tips of the bow arc)
        let topTip = CGPoint(x: -50 * cos(.pi * 0.3), y: 50 * sin(.pi * 0.3))
        let bottomTip = CGPoint(x: -50 * cos(.pi * 0.7), y: 50 * sin(.pi * 0.7))
        let pullPoint = CGPoint(x: -pullBack, y: 0)

        stringPath.move(to: topTip)
        stringPath.addLine(to: pullPoint)
        stringPath.addLine(to: bottomTip)

        bowString = SKShapeNode(path: stringPath)
        bowString.strokeColor = UIColor(red: 0.75, green: 0.70, blue: 0.55, alpha: 1)
        bowString.lineWidth = 2
        bowString.fillColor = .clear
        bowString.zPosition = 1
        bowNode.addChild(bowString)
    }

    // MARK: - Arrow

    private func nockArrow() {
        guard gameState?.arrowsRemaining ?? 0 > 0,
              gameState?.phase != .gameOver else { return }

        arrowNode?.removeFromParent()

        let arrow = SKNode()
        arrow.zPosition = 11

        // Arrow shaft
        let shaft = SKShapeNode(rectOf: CGSize(width: 60, height: 3))
        shaft.fillColor = UIColor(red: 0.55, green: 0.45, blue: 0.30, alpha: 1)
        shaft.strokeColor = .clear
        arrow.addChild(shaft)

        // Broadhead
        let headPath = CGMutablePath()
        headPath.move(to: CGPoint(x: 30, y: 0))
        headPath.addLine(to: CGPoint(x: 22, y: 5))
        headPath.addLine(to: CGPoint(x: 22, y: -5))
        headPath.closeSubpath()
        let head = SKShapeNode(path: headPath)
        head.fillColor = UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
        head.strokeColor = .clear
        arrow.addChild(head)

        // Fletching
        for yOff: CGFloat in [-4, 4] {
            let fletch = SKShapeNode(rectOf: CGSize(width: 12, height: 2))
            fletch.fillColor = UIColor(red: 0.80, green: 0.20, blue: 0.15, alpha: 1)
            fletch.strokeColor = .clear
            fletch.position = CGPoint(x: -24, y: yOff)
            arrow.addChild(fletch)
        }

        arrow.position = bowNode.position
        arrowNode = arrow
        addChild(arrow)

        gameState?.phase = .idle
    }

    private func launchArrow() {
        guard let arrow = arrowNode else { return }

        // Calculate velocity from draw vector
        let power = min(drawPower, 1.0)
        let magnitude = PhysicsConstants.minImpulseMagnitude +
                        (PhysicsConstants.maxImpulseMagnitude - PhysicsConstants.minImpulseMagnitude) * power

        let angle = atan2(drawVector.dy, drawVector.dx)
        let vx = cos(angle) * magnitude / PhysicsConstants.arrowMass
        let vy = sin(angle) * magnitude / PhysicsConstants.arrowMass
        let g = PhysicsConstants.gravity

        let startPos = arrow.position
        arrow.zRotation = angle

        // Haptic release thump
        releaseHaptic.impactOccurred(intensity: 1.0)

        // State update
        gameState?.arrowFired()
        arrowNode = nil

        // Fly the arrow along a parabolic arc using SKAction
        let flightDuration: TimeInterval = 4.0
        let groundY: CGFloat = 60

        let flyAction = SKAction.customAction(withDuration: flightDuration) { [weak self] node, elapsed in
            guard let self = self, node.parent != nil else { return }
            // Check if already stopped (userData flag)
            if node.userData?["stopped"] as? Bool == true { return }

            let t = CGFloat(elapsed)
            let x = startPos.x + vx * t
            let y = startPos.y + vy * t + 0.5 * g * t * t
            node.position = CGPoint(x: x, y: y)
            node.zRotation = atan2(vy + g * t, vx)

            // Check ground hit
            if y <= groundY {
                node.userData?["stopped"] = true
                self.handleArrowHitGround(arrow: node)
                return
            }

            // Check deer hit
            let arrowPoint = node.position
            for child in self.children where child.name == "deer" {
                let deerFrame = child.calculateAccumulatedFrame()
                if deerFrame.contains(arrowPoint) {
                    let points = (child.userData?["points"] as? Int) ?? 10
                    node.userData?["stopped"] = true
                    self.handleArrowHitDeer(arrow: node, deer: child, points: points)
                    return
                }
            }
        }

        arrow.userData = arrow.userData ?? NSMutableDictionary()

        let cleanup = SKAction.run { [weak self] in
            guard let self = self else { return }
            if arrow.parent != nil && arrow.userData?["stopped"] as? Bool != true {
                arrow.removeFromParent()
                if self.gameState?.phase == .fired {
                    self.gameState?.arrowMissed()
                }
                self.nockArrow()
            }
        }

        arrow.run(SKAction.sequence([flyAction, cleanup]))
    }

    private func handleArrowHitGround(arrow: SKNode) {
        arrow.removeAllActions()
        arrow.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))

        if gameState?.phase == .fired {
            gameState?.arrowMissed()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.nockArrow()
        }
    }

    private func handleArrowHitDeer(arrow: SKNode, deer: SKNode, points: Int) {
        arrow.removeAllActions()

        // Stop arrow
        arrow.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))

        // Remove deer
        deer.removeAllActions()
        deer.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.scale(to: 1.3, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))

        // Score
        showScoreBurst(points: points, at: arrow.position)
        gameState?.deerHit(points: points)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.nockArrow()
        }
    }

    // MARK: - Trajectory Preview

    private func updateTrajectoryPreview() {
        clearTrajectoryDots()

        guard drawPower > 0.1 else { return }

        let power = min(drawPower, 1.0)
        let magnitude = PhysicsConstants.minImpulseMagnitude +
                        (PhysicsConstants.maxImpulseMagnitude - PhysicsConstants.minImpulseMagnitude) * power
        let angle = atan2(drawVector.dy, drawVector.dx)

        let vx = cos(angle) * magnitude / PhysicsConstants.arrowMass
        let vy = sin(angle) * magnitude / PhysicsConstants.arrowMass
        let g = PhysicsConstants.gravity

        let startPos = bowNode.position

        for i in 0..<PhysicsConstants.trajectoryDotCount {
            let t = CGFloat(i + 1) * PhysicsConstants.trajectoryTimeStep
            let x = startPos.x + vx * t
            let y = startPos.y + vy * t + 0.5 * g * t * t

            guard y > 50 else { break } // Don't draw below ground

            let dot = SKShapeNode(circleOfRadius: PhysicsConstants.trajectoryDotRadius)
            let alpha = 1.0 - (CGFloat(i) / CGFloat(PhysicsConstants.trajectoryDotCount))
            dot.fillColor = UIColor(red: 1.0, green: 0.90, blue: 0.60, alpha: alpha * 0.7)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: x, y: y)
            dot.zPosition = 9
            addChild(dot)
            trajectoryDots.append(dot)
        }
    }

    private func clearTrajectoryDots() {
        trajectoryDots.forEach { $0.removeFromParent() }
        trajectoryDots.removeAll()
    }

    // MARK: - Deer Spawning

    private func spawnDeer() {
        let deerCount = children.filter { $0.name == "deer" }.count
        guard deerCount < PhysicsConstants.maxDeerOnScreen else { return }

        let rack = DeerInfo.RackSize.random()
        let speed = CGFloat.random(in: PhysicsConstants.deerMinSpeed...PhysicsConstants.deerMaxSpeed)
        let goingRight = Bool.random()

        // Deer Y: in the clearing band (screen height 30%–55%)
        let minY = size.height * 0.20
        let maxY = size.height * 0.50
        let deerY = CGFloat.random(in: minY...maxY)

        let startX: CGFloat = goingRight ? -rack.bodySize.width : size.width + rack.bodySize.width
        let endX: CGFloat = goingRight ? size.width + rack.bodySize.width : -rack.bodySize.width

        let deer = createDeerNode(rack: rack, facingRight: goingRight)
        deer.name = "deer"
        deer.position = CGPoint(x: startX, y: deerY)
        deer.userData = NSMutableDictionary()
        deer.userData?["points"] = rack.points
        deer.zPosition = 3

        // Size-based physics body for collision
        let body = SKPhysicsBody(rectangleOf: rack.bodySize)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.deer
        body.contactTestBitMask = PhysicsCategory.arrow
        deer.physicsBody = body

        addChild(deer)

        // Move across screen
        let duration = TimeInterval(size.width / speed)
        let moveAction = SKAction.moveTo(x: endX, duration: duration)
        let removeAction = SKAction.removeFromParent()
        deer.run(SKAction.sequence([moveAction, removeAction]))
    }

    private func createDeerNode(rack: DeerInfo.RackSize, facingRight: Bool) -> SKNode {
        let deer = SKNode()
        let s = rack.bodySize

        // Body
        let body = SKShapeNode(ellipseOf: s)
        body.fillColor = rack.color
        body.strokeColor = .clear
        deer.addChild(body)

        // Head
        let headSize = CGSize(width: s.width * 0.4, height: s.height * 0.75)
        let head = SKShapeNode(ellipseOf: headSize)
        head.fillColor = rack.color
        head.strokeColor = .clear
        let headX: CGFloat = facingRight ? s.width * 0.45 : -s.width * 0.45
        head.position = CGPoint(x: headX, y: s.height * 0.35)
        deer.addChild(head)

        // Antlers
        let antlerNode = SKShapeNode()
        let antlerPath = CGMutablePath()
        let antlerHeight = s.height * 0.6
        let antlerWidth = s.width * 0.3
        let baseY: CGFloat = 0

        // Left beam
        antlerPath.move(to: CGPoint(x: -2, y: baseY))
        antlerPath.addLine(to: CGPoint(x: -antlerWidth, y: antlerHeight))
        // Right beam
        antlerPath.move(to: CGPoint(x: 2, y: baseY))
        antlerPath.addLine(to: CGPoint(x: antlerWidth, y: antlerHeight))

        // Tines
        let tinesPerSide = rack.antlerPoints / 2
        for i in 0..<tinesPerSide {
            let progress = CGFloat(i + 1) / CGFloat(tinesPerSide + 1)
            let y = baseY + antlerHeight * progress
            let xL = -antlerWidth * progress
            let xR = antlerWidth * progress
            antlerPath.move(to: CGPoint(x: xL, y: y))
            antlerPath.addLine(to: CGPoint(x: xL - 6, y: y + 10))
            antlerPath.move(to: CGPoint(x: xR, y: y))
            antlerPath.addLine(to: CGPoint(x: xR + 6, y: y + 10))
        }

        antlerNode.path = antlerPath
        antlerNode.strokeColor = UIColor(red: 0.30, green: 0.20, blue: 0.10, alpha: 1)
        antlerNode.lineWidth = 2
        antlerNode.position = CGPoint(x: headX, y: s.height * 0.65)
        deer.addChild(antlerNode)

        // Legs
        for i in 0..<4 {
            let leg = SKShapeNode(rectOf: CGSize(width: 3, height: s.height * 0.5))
            leg.fillColor = rack.color
            leg.strokeColor = .clear
            let legX = CGFloat(i) * (s.width * 0.2) - s.width * 0.3
            leg.position = CGPoint(x: legX, y: -s.height * 0.45)
            deer.addChild(leg)
        }

        if !facingRight {
            deer.xScale = -1
        }

        return deer
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              gameState?.phase == .idle,
              gameState?.isGameActive == true else { return }

        let location = touch.location(in: self)

        // Start drawing if touch is near the bow area (generous touch target)
        let bowPos = bowNode.position
        let dist = hypot(location.x - bowPos.x, location.y - bowPos.y)
        if dist < 80 {
            isDrawing = true
            drawAnchor = location
            drawVector = .zero
            drawPower = 0
            lastHapticThreshold = 0
            gameState?.phase = .aiming
            lightHaptic.impactOccurred()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawing, let touch = touches.first else { return }

        let location = touch.location(in: self)

        // Draw vector: from current touch back toward anchor = aim direction is opposite
        let dx = drawAnchor.x - location.x
        let dy = drawAnchor.y - location.y
        let distance = hypot(dx, dy)
        let clampedDist = min(distance, PhysicsConstants.maxDrawDistance)

        drawPower = clampedDist / PhysicsConstants.maxDrawDistance

        // The aim direction: opposite of pull (pull down-left = shoot up-right)
        drawVector = CGVector(dx: dx, dy: dy)

        // Normalize if over max
        if distance > PhysicsConstants.maxDrawDistance {
            let scale = PhysicsConstants.maxDrawDistance / distance
            drawVector = CGVector(dx: dx * scale, dy: dy * scale)
        }

        // Update bow string visual
        updateBowString(pullBack: clampedDist * 0.2)

        // Move nocked arrow back with the string
        if let arrow = arrowNode {
            let pullOffset = clampedDist * 0.2
            arrow.position = CGPoint(x: bowNode.position.x - pullOffset,
                                     y: bowNode.position.y)
            // Rotate arrow to match aim direction
            let angle = atan2(drawVector.dy, drawVector.dx)
            arrow.zRotation = angle
        }

        // Progressive haptics
        triggerDrawHaptics()

        // Update trajectory preview
        updateTrajectoryPreview()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("[HuntingScene] touchesEnded — isDrawing=\(isDrawing), drawPower=\(drawPower), drawVector=\(drawVector)")
        guard isDrawing else { print("[HuntingScene] touchesEnded SKIPPED — not drawing"); return }
        isDrawing = false

        clearTrajectoryDots()
        updateBowString(pullBack: 0)

        if drawPower > 0.1 {
            print("[HuntingScene] launching arrow with power=\(drawPower)")
            launchArrow()
        } else {
            // Too weak a draw — reset
            arrowNode?.position = bowNode.position
            arrowNode?.zRotation = 0
            gameState?.phase = .idle
        }

        drawVector = .zero
        drawPower = 0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Haptics

    private func triggerDrawHaptics() {
        if drawPower >= PhysicsConstants.drawThresholdFull && lastHapticThreshold < PhysicsConstants.drawThresholdFull {
            heavyHaptic.impactOccurred(intensity: PhysicsConstants.hapticHeavyIntensity)
            lastHapticThreshold = PhysicsConstants.drawThresholdFull
        } else if drawPower >= PhysicsConstants.drawThresholdHalf && lastHapticThreshold < PhysicsConstants.drawThresholdHalf {
            mediumHaptic.impactOccurred(intensity: PhysicsConstants.hapticMediumIntensity)
            lastHapticThreshold = PhysicsConstants.drawThresholdHalf
        } else if drawPower >= PhysicsConstants.drawThresholdQuarter && lastHapticThreshold < PhysicsConstants.drawThresholdQuarter {
            lightHaptic.impactOccurred(intensity: PhysicsConstants.hapticLightIntensity)
            lastHapticThreshold = PhysicsConstants.drawThresholdQuarter
        }
    }

    // MARK: - Physics Contact (unused — arrow flight uses SKAction trajectory)

    func didBegin(_ contact: SKPhysicsContact) {
        // Kept for protocol conformance; collision detection is handled
        // in the arrow's customAction flight loop.
    }

    // MARK: - Score Burst

    private func showScoreBurst(points: Int, at position: CGPoint) {
        let label = SKLabelNode(text: "+\(points)")
        label.fontName = "Georgia-Bold"
        label.fontSize = 36
        label.fontColor = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1)
        label.position = position
        label.zPosition = 20
        addChild(label)

        let rise = SKAction.moveBy(x: 0, y: 60, duration: 0.8)
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let scale = SKAction.scale(to: 1.5, duration: 0.8)
        label.run(SKAction.sequence([
            SKAction.group([rise, fade, scale]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard gameState?.phase != .gameOver else { return }

        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Spawn deer
        deerSpawnAccumulator += dt
        if deerSpawnAccumulator >= PhysicsConstants.deerSpawnInterval {
            deerSpawnAccumulator = 0
            spawnDeer()
        }

        // Countdown timer
        countdownAccumulator += dt
        if countdownAccumulator >= 1.0 {
            countdownAccumulator = 0
            gameState?.tick()
        }
    }
}
