import SwiftUI
import SpriteKit

struct HuntingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameState = GameState()
    @State private var sceneId = UUID()
    @State private var scene: HuntingScene?

    private func makeScene(size: CGSize) -> HuntingScene {
        let s = HuntingScene(size: size)
        s.scaleMode = .resizeFill
        s.gameState = gameState
        return s
    }

    var body: some View {
        GeometryReader { geo in
        ZStack {
            // SpriteKit game scene
            if let scene = scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
                    .id(sceneId)
            }

            // HUD overlay
            VStack {
                HuntingHUD(
                    score: gameState.score,
                    arrows: gameState.arrowsRemaining,
                    time: gameState.timeRemaining
                )
                Spacer()
            }
            .padding()

            // Score feedback
            if let points = gameState.lastHitPoints {
                Text("+\(points)")
                    .font(.system(size: 48, weight: .black, design: .serif))
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                    .shadow(color: .black, radius: 4)
                    .transition(.opacity.combined(with: .offset(y: -30)))
                    .animation(.easeOut(duration: 0.6), value: gameState.lastHitPoints)
            }

            if gameState.showMiss {
                Text("MISS")
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .foregroundStyle(.red)
                    .shadow(color: .black, radius: 3)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.4), value: gameState.showMiss)
            }

            // Game over overlay
            if gameState.phase == .gameOver {
                GameOverOverlay(
                    score: gameState.score,
                    onPlayAgain: {
                        gameState.reset()
                        sceneId = UUID()
                    },
                    onQuit: { dismiss() }
                )
            }
        }
        .onAppear {
            if scene == nil {
                scene = makeScene(size: geo.size)
            }
        }
        .onChange(of: sceneId) {
            scene = makeScene(size: geo.size)
        }
        } // GeometryReader
    }
}

// MARK: - HUD

struct HuntingHUD: View {
    let score: Int
    let arrows: Int
    let time: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCORE")
                    .font(.caption).bold()
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(score)")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(.white)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("ARROWS")
                    .font(.caption).bold()
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(arrows)")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(arrows <= 3 ? .red : .white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("TIME")
                    .font(.caption).bold()
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(time)s")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(time <= 10 ? .red : .white)
            }
        }
        .padding()
        .background(.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 40)
    }
}

// MARK: - Game Over

struct GameOverOverlay: View {
    let score: Int
    let onPlayAgain: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("SEASON'S OVER")
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .foregroundStyle(.white)

                Text("Final Score")
                    .font(.system(size: 18, design: .serif))
                    .foregroundStyle(.white.opacity(0.7))

                Text("\(score)")
                    .font(.system(size: 72, weight: .black, design: .serif))
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))

                Text(rating(for: score))
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Button(action: onQuit) {
                        Text("CAMP")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.3, green: 0.2, blue: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(action: onPlayAgain) {
                        Text("HUNT AGAIN")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.45, green: 0.30, blue: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(40)
        }
    }

    private func rating(for score: Int) -> String {
        switch score {
        case 0..<50:   return "Maybe try the dove field next time."
        case 50..<150:  return "Not bad. Coffee's on you."
        case 150..<300: return "Now that's a freezer worth fillin'."
        case 300..<500: return "Word's gonna get around the county."
        default:        return "Legendary. They'll be tellin' stories about this one."
        }
    }
}
