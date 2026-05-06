import SpriteKit
import UIKit

// MARK: - UIColor Helpers

extension UIColor {
    func darker(by factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - factor, 0), green: max(g - factor, 0),
                       blue: max(b - factor, 0), alpha: a)
    }

    func lighter(by factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(r + factor, 1), green: min(g + factor, 1),
                       blue: min(b + factor, 1), alpha: a)
    }
}

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
    private var bowNode: SKNode!                // Invisible anchor point for arrow position
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

    // MARK: - Bow (invisible anchor)

    private func setupBow() {
        let bowX = size.width / 2
        let bowY = PhysicsConstants.bowYOffset

        bowNode = SKNode()
        bowNode.position = CGPoint(x: bowX, y: bowY)
        bowNode.zPosition = 10
        addChild(bowNode)
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

            // Check treeline boundary (arrow has gone past the clearing)
            let treelineY = self.size.height * 0.57
            if y >= treelineY {
                node.userData?["stopped"] = true
                self.handleArrowHitGround(arrow: node)
                return
            }

            // Check off-screen left/right
            if x < -50 || x > self.size.width + 50 {
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
        let scale = s.width / 80.0  // normalize to reference size

        let baseColor = rack.color
        let darkColor = baseColor.darker(by: 0.25)
        let lightColor = baseColor.lighter(by: 0.20)
        let bellyColor = baseColor.lighter(by: 0.35)
        let antlerColor = UIColor(red: 0.30, green: 0.22, blue: 0.12, alpha: 1)

        // --- Layer 1: Body silhouette (organic shape with bezier curves) ---
        let bodyPath = CGMutablePath()
        // Start at chest, go along back, down rump, under belly, back to chest
        bodyPath.move(to: p(22, 8, scale))
        // Shoulder hump
        bodyPath.addCurve(to: p(8, 18, scale),
                          control1: p(18, 16, scale),
                          control2: p(12, 20, scale))
        // Back line with slight dip
        bodyPath.addCurve(to: p(-20, 16, scale),
                          control1: p(0, 19, scale),
                          control2: p(-10, 18, scale))
        // Rump curve
        bodyPath.addCurve(to: p(-30, 4, scale),
                          control1: p(-26, 15, scale),
                          control2: p(-30, 10, scale))
        // Under rump
        bodyPath.addCurve(to: p(-22, -6, scale),
                          control1: p(-31, -2, scale),
                          control2: p(-28, -5, scale))
        // Belly
        bodyPath.addCurve(to: p(8, -8, scale),
                          control1: p(-12, -10, scale),
                          control2: p(0, -11, scale))
        // Chest
        bodyPath.addCurve(to: p(22, 8, scale),
                          control1: p(16, -6, scale),
                          control2: p(22, 0, scale))
        bodyPath.closeSubpath()

        let bodyNode = SKShapeNode(path: bodyPath)
        bodyNode.fillColor = baseColor
        bodyNode.strokeColor = darkColor
        bodyNode.lineWidth = 0.5 * scale
        deer.addChild(bodyNode)

        // --- Layer 2: Belly highlight ---
        let bellyPath = CGMutablePath()
        bellyPath.move(to: p(14, -4, scale))
        bellyPath.addCurve(to: p(-20, -3, scale),
                           control1: p(4, -9, scale),
                           control2: p(-8, -8, scale))
        bellyPath.addCurve(to: p(-14, 0, scale),
                           control1: p(-18, -1, scale),
                           control2: p(-16, 0, scale))
        bellyPath.addCurve(to: p(14, -4, scale),
                           control1: p(-2, -4, scale),
                           control2: p(8, -6, scale))
        bellyPath.closeSubpath()

        let bellyNode = SKShapeNode(path: bellyPath)
        bellyNode.fillColor = bellyColor
        bellyNode.strokeColor = .clear
        deer.addChild(bellyNode)

        // --- Layer 3: Shoulder shadow ---
        let shoulderPath = CGMutablePath()
        shoulderPath.move(to: p(18, 14, scale))
        shoulderPath.addCurve(to: p(8, 18, scale),
                              control1: p(14, 18, scale),
                              control2: p(10, 19, scale))
        shoulderPath.addCurve(to: p(6, 6, scale),
                              control1: p(6, 14, scale),
                              control2: p(5, 10, scale))
        shoulderPath.addCurve(to: p(18, 14, scale),
                              control1: p(10, 6, scale),
                              control2: p(16, 10, scale))
        shoulderPath.closeSubpath()

        let shoulderNode = SKShapeNode(path: shoulderPath)
        shoulderNode.fillColor = darkColor
        shoulderNode.strokeColor = .clear
        deer.addChild(shoulderNode)

        // --- Layer 4: Neck ---
        let neckPath = CGMutablePath()
        neckPath.move(to: p(22, 8, scale))
        neckPath.addCurve(to: p(30, 18, scale),
                          control1: p(24, 12, scale),
                          control2: p(26, 16, scale))
        neckPath.addCurve(to: p(28, 24, scale),
                          control1: p(32, 20, scale),
                          control2: p(30, 22, scale))
        neckPath.addCurve(to: p(18, 16, scale),
                          control1: p(24, 22, scale),
                          control2: p(20, 18, scale))
        neckPath.closeSubpath()

        let neckNode = SKShapeNode(path: neckPath)
        neckNode.fillColor = baseColor
        neckNode.strokeColor = darkColor
        neckNode.lineWidth = 0.5 * scale
        deer.addChild(neckNode)

        // --- Layer 5: Head ---
        let headPath = CGMutablePath()
        headPath.move(to: p(28, 24, scale))
        // Forehead
        headPath.addCurve(to: p(38, 26, scale),
                          control1: p(30, 28, scale),
                          control2: p(34, 28, scale))
        // Snout
        headPath.addCurve(to: p(42, 22, scale),
                          control1: p(40, 26, scale),
                          control2: p(42, 24, scale))
        // Nose tip
        headPath.addCurve(to: p(40, 19, scale),
                          control1: p(42, 20, scale),
                          control2: p(42, 19, scale))
        // Jaw line
        headPath.addCurve(to: p(30, 18, scale),
                          control1: p(38, 18, scale),
                          control2: p(34, 17, scale))
        headPath.addCurve(to: p(28, 24, scale),
                          control1: p(28, 20, scale),
                          control2: p(28, 22, scale))
        headPath.closeSubpath()

        let headNode = SKShapeNode(path: headPath)
        headNode.fillColor = baseColor
        headNode.strokeColor = darkColor
        headNode.lineWidth = 0.5 * scale
        deer.addChild(headNode)

        // --- Layer 6: Nose ---
        let nosePath = CGMutablePath()
        nosePath.addEllipse(in: CGRect(x: 39 * scale, y: 19.5 * scale,
                                        width: 3.5 * scale, height: 2.5 * scale))
        let noseNode = SKShapeNode(path: nosePath)
        noseNode.fillColor = UIColor(red: 0.15, green: 0.10, blue: 0.08, alpha: 1)
        noseNode.strokeColor = .clear
        deer.addChild(noseNode)

        // --- Layer 7: Eye ---
        let eyeX: CGFloat = 34 * scale
        let eyeY: CGFloat = 25 * scale
        let eye = SKShapeNode(circleOfRadius: 1.5 * scale)
        eye.fillColor = UIColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 1)
        eye.strokeColor = .clear
        eye.position = CGPoint(x: eyeX, y: eyeY)
        deer.addChild(eye)

        // Eye glint
        let glint = SKShapeNode(circleOfRadius: 0.6 * scale)
        glint.fillColor = .white
        glint.strokeColor = .clear
        glint.position = CGPoint(x: eyeX + 0.5 * scale, y: eyeY + 0.5 * scale)
        deer.addChild(glint)

        // --- Layer 8: Ear ---
        let earPath = CGMutablePath()
        earPath.move(to: p(30, 27, scale))
        earPath.addCurve(to: p(27, 32, scale),
                         control1: p(28, 30, scale),
                         control2: p(26, 32, scale))
        earPath.addCurve(to: p(32, 28, scale),
                         control1: p(28, 32, scale),
                         control2: p(31, 30, scale))
        earPath.closeSubpath()

        let earNode = SKShapeNode(path: earPath)
        earNode.fillColor = lightColor
        earNode.strokeColor = darkColor
        earNode.lineWidth = 0.5 * scale
        deer.addChild(earNode)

        // Inner ear
        let innerEarPath = CGMutablePath()
        innerEarPath.move(to: p(30, 27.5, scale))
        innerEarPath.addCurve(to: p(28, 31, scale),
                              control1: p(29, 29.5, scale),
                              control2: p(27.5, 31, scale))
        innerEarPath.addCurve(to: p(31, 28, scale),
                              control1: p(28.5, 31, scale),
                              control2: p(30.5, 29.5, scale))
        innerEarPath.closeSubpath()

        let innerEarNode = SKShapeNode(path: innerEarPath)
        innerEarNode.fillColor = UIColor(red: 0.75, green: 0.55, blue: 0.45, alpha: 1)
        innerEarNode.strokeColor = .clear
        deer.addChild(innerEarNode)

        // --- Layer 9: Tail ---
        let tailPath = CGMutablePath()
        tailPath.move(to: p(-30, 6, scale))
        tailPath.addCurve(to: p(-35, 12, scale),
                          control1: p(-33, 8, scale),
                          control2: p(-36, 10, scale))
        tailPath.addCurve(to: p(-31, 8, scale),
                          control1: p(-35, 14, scale),
                          control2: p(-32, 10, scale))
        tailPath.closeSubpath()

        let tailNode = SKShapeNode(path: tailPath)
        tailNode.fillColor = .white
        tailNode.strokeColor = .clear
        deer.addChild(tailNode)

        // --- Layer 10: Legs (organic shaped with joints) ---
        let legPositions: [(x: CGFloat, isFront: Bool)] = [
            (16, true), (10, true), (-16, false), (-22, false)
        ]

        for (i, leg) in legPositions.enumerated() {
            let legPath = CGMutablePath()
            let lx = leg.x
            let legLen: CGFloat = leg.isFront ? 16 : 14
            let kneeOffset: CGFloat = leg.isFront ? 1.5 : -1.5
            // Slightly stagger paired legs for depth
            let isBack = (i == 0 || i == 2)

            // Upper leg
            legPath.move(to: p(lx - 1.5, -4, scale))
            legPath.addCurve(to: p(lx + kneeOffset - 1.2, -(4 + legLen * 0.55), scale),
                             control1: p(lx - 1.5, -(4 + legLen * 0.2), scale),
                             control2: p(lx + kneeOffset - 1.5, -(4 + legLen * 0.4), scale))
            // Lower leg
            legPath.addCurve(to: p(lx + 0.5, -(4 + legLen), scale),
                             control1: p(lx + kneeOffset - 0.8, -(4 + legLen * 0.7), scale),
                             control2: p(lx + 0.5, -(4 + legLen * 0.9), scale))
            // Hoof
            legPath.addLine(to: p(lx + 2.5, -(4 + legLen), scale))
            legPath.addLine(to: p(lx + 2.5, -(4 + legLen - 1.5), scale))
            // Back up
            legPath.addCurve(to: p(lx + kneeOffset + 1.2, -(4 + legLen * 0.55), scale),
                             control1: p(lx + 2, -(4 + legLen * 0.85), scale),
                             control2: p(lx + kneeOffset + 1.5, -(4 + legLen * 0.7), scale))
            legPath.addCurve(to: p(lx + 1.5, -4, scale),
                             control1: p(lx + kneeOffset + 1.5, -(4 + legLen * 0.35), scale),
                             control2: p(lx + 1.5, -(4 + legLen * 0.15), scale))
            legPath.closeSubpath()

            let legNode = SKShapeNode(path: legPath)
            legNode.fillColor = isBack ? darkColor : baseColor
            legNode.strokeColor = darkColor
            legNode.lineWidth = 0.3 * scale
            legNode.zPosition = isBack ? -1 : 1
            deer.addChild(legNode)

            // Hoof accent
            let hoofPath = CGMutablePath()
            hoofPath.addRect(CGRect(x: (lx - 0.5) * scale, y: -(4 + legLen) * scale,
                                     width: 3.5 * scale, height: 1.8 * scale))
            let hoofNode = SKShapeNode(path: hoofPath)
            hoofNode.fillColor = UIColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1)
            hoofNode.strokeColor = .clear
            hoofNode.zPosition = isBack ? -1 : 1
            deer.addChild(hoofNode)
        }

        // --- Layer 11: Antlers (organic curved beams with tines) ---
        let antlerBaseX: CGFloat = 31 * scale
        let antlerBaseY: CGFloat = 27 * scale
        let beamHeight = s.height * 0.5 + CGFloat(rack.antlerPoints) * 1.2 * scale
        let beamSpread = s.width * 0.18 + CGFloat(rack.antlerPoints) * 0.6 * scale
        let tinesPerSide = rack.antlerPoints / 2

        // Draw each beam as a filled shape for thickness
        for side: CGFloat in [-1, 1] {
            let beamPath = CGMutablePath()
            let spreadX = side * beamSpread
            let thickness: CGFloat = 1.2 * scale

            // Inner edge of beam
            beamPath.move(to: CGPoint(x: antlerBaseX - side * 1 * scale, y: antlerBaseY))
            beamPath.addCurve(
                to: CGPoint(x: antlerBaseX + spreadX, y: antlerBaseY + beamHeight),
                control1: CGPoint(x: antlerBaseX + spreadX * 0.3, y: antlerBaseY + beamHeight * 0.4),
                control2: CGPoint(x: antlerBaseX + spreadX * 0.7, y: antlerBaseY + beamHeight * 0.7)
            )
            // Tip
            beamPath.addLine(to: CGPoint(x: antlerBaseX + spreadX + side * thickness, y: antlerBaseY + beamHeight - thickness))
            // Outer edge back down
            beamPath.addCurve(
                to: CGPoint(x: antlerBaseX + side * 1 * scale, y: antlerBaseY),
                control1: CGPoint(x: antlerBaseX + spreadX * 0.7 + side * thickness, y: antlerBaseY + beamHeight * 0.65),
                control2: CGPoint(x: antlerBaseX + spreadX * 0.3 + side * thickness, y: antlerBaseY + beamHeight * 0.35)
            )
            beamPath.closeSubpath()

            let beamNode = SKShapeNode(path: beamPath)
            beamNode.fillColor = antlerColor
            beamNode.strokeColor = antlerColor.lighter(by: 0.15)
            beamNode.lineWidth = 0.3 * scale
            deer.addChild(beamNode)

            // Tines branching off the beam
            for i in 0..<tinesPerSide {
                let progress = CGFloat(i + 1) / CGFloat(tinesPerSide + 1)
                let tineBaseX = antlerBaseX + spreadX * progress
                let tineBaseY = antlerBaseY + beamHeight * progress
                let tineLen: CGFloat = (4 + CGFloat(i) * 1.5) * scale
                let tineAngle: CGFloat = side > 0 ? 0.4 : -0.4

                let tinePath = CGMutablePath()
                tinePath.move(to: CGPoint(x: tineBaseX, y: tineBaseY))
                tinePath.addLine(to: CGPoint(x: tineBaseX + side * tineLen * cos(tineAngle),
                                              y: tineBaseY + tineLen * sin(tineAngle) + tineLen * 0.6))
                tinePath.addLine(to: CGPoint(x: tineBaseX + side * 0.8 * scale, y: tineBaseY + 0.5 * scale))
                tinePath.closeSubpath()

                let tineNode = SKShapeNode(path: tinePath)
                tineNode.fillColor = antlerColor
                tineNode.strokeColor = .clear
                deer.addChild(tineNode)
            }
        }

        // --- Layer 12: Rump patch (subtle lighter area) ---
        let rumpPath = CGMutablePath()
        rumpPath.move(to: p(-24, 10, scale))
        rumpPath.addCurve(to: p(-28, 2, scale),
                          control1: p(-28, 8, scale),
                          control2: p(-30, 4, scale))
        rumpPath.addCurve(to: p(-20, 8, scale),
                          control1: p(-26, 0, scale),
                          control2: p(-22, 4, scale))
        rumpPath.addCurve(to: p(-24, 10, scale),
                          control1: p(-20, 10, scale),
                          control2: p(-22, 10, scale))
        rumpPath.closeSubpath()

        let rumpNode = SKShapeNode(path: rumpPath)
        rumpNode.fillColor = lightColor
        rumpNode.strokeColor = .clear
        deer.addChild(rumpNode)

        // Flip for direction
        if !facingRight {
            deer.xScale = -1
        }

        return deer
    }

    /// Helper to scale design coordinates
    private func p(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) -> CGPoint {
        return CGPoint(x: x * scale, y: y * scale)
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

        // Rotate arrow to aim direction (stays at bow position, just rotates)
        if let arrow = arrowNode {
            let angle = atan2(drawVector.dy, drawVector.dx)
            arrow.zRotation = angle
        }

        // Progressive haptics
        triggerDrawHaptics()

        // Update trajectory preview
        updateTrajectoryPreview()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawing else { return }
        isDrawing = false

        clearTrajectoryDots()

        if drawPower > 0.1 {
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
