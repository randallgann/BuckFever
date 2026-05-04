import Foundation

struct PhysicsConstants {
    // MARK: - Gravity & World
    static let gravity: CGFloat = -6.0          // SpriteKit gravity Y
    static let worldEdgeBuffer: CGFloat = 100   // Off-screen buffer before cleanup

    // MARK: - Arrow
    static let arrowMass: CGFloat = 0.15
    static let arrowLinearDamping: CGFloat = 0.3
    static let arrowAngularDamping: CGFloat = 0.8
    static let maxImpulseMagnitude: CGFloat = 90.0
    static let minImpulseMagnitude: CGFloat = 20.0
    static let impulseMultiplier: CGFloat = 0.18  // Maps drag distance to impulse

    // MARK: - Draw / Aiming
    static let maxDrawDistance: CGFloat = 200     // Max pull-back in points
    static let drawThresholdQuarter: CGFloat = 0.25
    static let drawThresholdHalf: CGFloat = 0.50
    static let drawThresholdFull: CGFloat = 0.85

    // MARK: - Trajectory Preview
    static let trajectoryDotCount: Int = 12
    static let trajectoryDotRadius: CGFloat = 3.0
    static let trajectoryTimeStep: CGFloat = 0.08 // Seconds between dots
    static let trajectoryMaxPercent: CGFloat = 0.35 // Show ~35% of full arc

    // MARK: - Deer / Bucks
    static let deerMinSpeed: CGFloat = 80        // Points per second
    static let deerMaxSpeed: CGFloat = 180
    static let deerSpawnInterval: TimeInterval = 2.5
    static let maxDeerOnScreen: Int = 3

    // MARK: - Bow
    static let bowYOffset: CGFloat = 80          // Distance from bottom of screen
    static let bowScale: CGFloat = 0.5
    static let bowStringMaxPull: CGFloat = 40    // Visual string displacement

    // MARK: - Haptics
    static let hapticLightIntensity: CGFloat = 0.3
    static let hapticMediumIntensity: CGFloat = 0.6
    static let hapticHeavyIntensity: CGFloat = 1.0
}
