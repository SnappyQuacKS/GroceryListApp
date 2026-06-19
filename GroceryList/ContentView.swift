import SwiftUI

struct ContentView: View {
    @State private var store = AppStore()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var splashVisible = true
    @State private var splashOpacity: Double = 1

    var body: some View {
        ZStack {
            Group {
                if store.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environment(store)

            if splashVisible {
                SplashView()
                    .opacity(splashOpacity)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .task {
            // Launch splash — always shown for at least 1.5s
            await hideSplash(after: 1_500_000_000)
        }
        .onChange(of: store.isAuthenticated) { _, newValue in
            guard newValue, !splashVisible else { return }
            // Sign-in splash — re-show briefly when transitioning from login to app
            splashVisible = true
            splashOpacity = 1
            Task { await hideSplash(after: 1_200_000_000) }
        }
    }

    private func hideSplash(after nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
        withAnimation(.easeOut(duration: 0.5)) { splashOpacity = 0 }
        try? await Task.sleep(nanoseconds: 550_000_000)
        splashVisible = false
        splashOpacity = 1
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            LinedPaperBackground()
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 300)
        }
    }
}

#Preview {
    ContentView()
}
