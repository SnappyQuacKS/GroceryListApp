import SwiftUI

struct AccountSettingsView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var firstName  = ""
    @State private var lastName   = ""
    @State private var zipCode    = ""
    @State private var loaded     = false
    @State private var showSignOutAlert = false
    @FocusState private var activeField: SettingsField?

    enum SettingsField { case firstName, lastName, zipCode }

    private var hasChanges: Bool {
        guard loaded, let u = store.currentUser else { return false }
        return firstName != u.firstName || lastName != u.lastName || zipCode != u.zipCode
    }

    private var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        let s = (f + l).uppercased()
        return s.isEmpty ? "?" : s
    }

    private var displayEmail: String {
        store.currentUser?.username ?? (store.isGuest ? "Guest" : "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinedPaperBackground(showMargin: false)

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile fields — white rounded-box inputs
                        VStack(spacing: 14) {
                            settingsField(label: "First Name", text: $firstName, field: .firstName)
                            settingsField(label: "Last Name",  text: $lastName,  field: .lastName)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ZIP Code")
                                    .font(.custom("Kreon-Regular", size: 13).weight(.medium))
                                    .foregroundColor(.secondary)
                                TextField("", text: $zipCode)
                                    .font(.custom("Kreon-Regular", size: 20))
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                    .focused($activeField, equals: .zipCode)
                            }
                        }
                        .padding(.horizontal)

                        Button("Save Changes") {
                            store.updateCurrentUser(firstName: firstName,
                                                    lastName: lastName, zipCode: zipCode)
                            activeField = nil
                        }
                        .font(.custom("Kreon-Regular", size: 17))
                        .buttonStyle(GreenButtonStyle())
                        .padding(.horizontal)
                        .opacity(hasChanges ? 1 : 0.4)
                        .disabled(!hasChanges)

                        Divider().padding(.horizontal)

                        // Dark mode toggle
                        HStack {
                            Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(isDarkMode ? .indigo : .orange)
                                .font(.system(size: 18))
                            Text(isDarkMode ? "Dark Mode" : "Light Mode")
                                .font(.custom("Kreon-Regular", size: 16))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { isDarkMode },
                                set: { newValue in
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        isDarkMode = newValue
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(Color(red: 0.15, green: 0.55, blue: 0.38))
                        }
                        .padding(.horizontal)

                        Divider().padding(.horizontal)

                        VStack(spacing: 14) {
                            Button("Terms of Service") {}
                                .font(.custom("Kreon-Regular", size: 16))
                                .foregroundColor(Color(red: 0.15, green: 0.55, blue: 0.38))

                            Button("Sign Out") { showSignOutAlert = true }
                                .font(.custom("Kreon-Regular", size: 17))
                                .buttonStyle(RedOutlineButtonStyle())
                                .padding(.horizontal)
                        }

                        Spacer().frame(height: 20)
                    }
                }
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Account Settings")
                        .font(.custom("Kreon-Bold", size: 40))
                }
            }
        }
        .onAppear { syncFromStore() }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) { store.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    @ViewBuilder
    private func settingsField(label: String, text: Binding<String>, field: SettingsField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Kreon-Regular", size: 13).weight(.medium))
                .foregroundColor(.secondary)
            TextField("", text: text)
                .font(.custom("Kreon-Regular", size: 20))
                .textFieldStyle(.roundedBorder)
                .focused($activeField, equals: field)
        }
    }

    private func syncFromStore() {
        firstName = store.currentUser?.firstName ?? ""
        lastName  = store.currentUser?.lastName  ?? ""
        zipCode   = store.currentUser?.zipCode   ?? ""
        loaded    = true
    }
}

// MARK: - Shared button styles

struct RedOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.75, green: 0.18, blue: 0.18))
            .foregroundColor(.white)
            .fontWeight(.medium)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.75, green: 0.18, blue: 0.18), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
