import SwiftUI

struct ContentView: View {
    @State private var showGame = false

    var body: some View {
        ZStack {
            // Background — piney woods feel
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.25, blue: 0.15),
                         Color(red: 0.05, green: 0.10, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("PINEYWOODS BUCK DRAW")
                    .font(.system(size: 56, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 4, x: 2, y: 2)

                Text("East Texas Edition")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.85, green: 0.75, blue: 0.5))
                    .italic()

                Spacer()

                Button {
                    showGame = true
                } label: {
                    Text("HUNT")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.45, green: 0.30, blue: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black, radius: 6, x: 0, y: 3)
                }

                Spacer()

                Text("Draw your bow. Steady your aim.")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                    .italic()
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showGame) {
            HuntingView()
        }
    }
}

#Preview {
    ContentView()
}
