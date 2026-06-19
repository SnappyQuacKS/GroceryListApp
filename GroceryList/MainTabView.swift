import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    private let green = Color(red: 0.15, green: 0.55, blue: 0.38)

    var body: some View {
        ZStack(alignment: .bottom) {
            HomeView()
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)
            AccountSettingsView()
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)

            // Floating pill tab bar
            HStack(spacing: 0) {
                tabButton(tag: 0, title: "Lists", icon: "list.bullet")
                tabButton(tag: 1, title: "Account", icon: "person.circle")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func tabButton(tag: Int, title: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tag
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedTab == tag ? filledIcon(icon) : icon)
                    .font(.system(size: 16, weight: .medium))
                if selectedTab == tag {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                }
            }
            .foregroundColor(selectedTab == tag ? .white : Color(uiColor: .systemGray))
            .padding(.horizontal, selectedTab == tag ? 16 : 18)
            .padding(.vertical, 10)
            .background {
                if selectedTab == tag {
                    Capsule().fill(green)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedTab)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func filledIcon(_ icon: String) -> String {
        switch icon {
        case "person.circle": return "person.circle.fill"
        default:              return icon
        }
    }
}
