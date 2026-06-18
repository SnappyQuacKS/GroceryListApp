import SwiftUI

struct ContentView: View {
    @State private var store = AppStore()
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        Group {
            if store.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environment(store)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

#Preview {
    ContentView()
}
