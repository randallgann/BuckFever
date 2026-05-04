import SwiftUI
import Combine

enum GamePhase {
    case idle       // Waiting, bow ready
    case aiming     // Player is drawing the bow
    case fired      // Arrow in flight
    case scored     // Arrow hit a deer
    case roundOver  // Arrow missed / landed
    case gameOver   // Time or arrows exhausted
}

class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var arrowsRemaining: Int = 15
    @Published var timeRemaining: Int = 60
    @Published var phase: GamePhase = .idle
    @Published var lastHitPoints: Int? = nil
    @Published var showMiss: Bool = false

    func reset() {
        score = 0
        arrowsRemaining = 15
        timeRemaining = 60
        phase = .idle
        lastHitPoints = nil
        showMiss = false
    }

    func arrowFired() {
        arrowsRemaining -= 1
        phase = .fired
    }

    func deerHit(points: Int) {
        score += points
        lastHitPoints = points
        showMiss = false
        phase = .scored

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.lastHitPoints = nil
            self?.phase = .idle
        }
    }

    func arrowMissed() {
        showMiss = true
        phase = .roundOver

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showMiss = false
            self?.phase = self?.arrowsRemaining ?? 0 > 0 ? .idle : .gameOver
        }
    }

    func tick() {
        guard phase != .gameOver else { return }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            phase = .gameOver
        }
    }

    var isGameActive: Bool {
        phase != .gameOver
    }
}
