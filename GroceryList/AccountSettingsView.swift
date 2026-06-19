import SwiftUI

struct AccountSettingsView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var zipCode    = ""
    @State private var loaded     = false
    @State private var showSignOutAlert = false
    @State private var showChangePassword = false
    @FocusState private var zipFocused: Bool

    private var hasChanges: Bool {
        guard loaded, let u = store.currentUser else { return false }
        return zipCode != u.zipCode
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinedPaperBackground(showMargin: false)

                ScrollView {
                    VStack(spacing: 24) {
                        if store.isGuest {
                            HStack(spacing: 14) {
                                Image(systemName: "person.fill.questionmark")
                                    .font(.system(size: 30))
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Guest Account")
                                        .font(.custom("Kreon-Bold", size: 18))
                                    Text("Sign in to sync your lists across devices")
                                        .font(.custom("Kreon-Regular", size: 13))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 14) {
                                readOnlyField(label: "Username",
                                              value: store.currentUser?.username ?? "")

                                // Password row with Change button
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Password")
                                        .font(.custom("Kreon-Regular", size: 13).weight(.medium))
                                        .foregroundColor(.secondary)
                                    HStack {
                                        Text("••••••••")
                                            .font(.system(size: 18))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Button("Change") { showChangePassword = true }
                                            .font(.custom("Kreon-Regular", size: 14))
                                            .foregroundColor(Color(red: 0.15, green: 0.55, blue: 0.38))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(uiColor: .systemFill))
                                    )
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ZIP Code")
                                        .font(.custom("Kreon-Regular", size: 13).weight(.medium))
                                        .foregroundColor(.secondary)
                                    TextField("", text: $zipCode)
                                        .font(.custom("Kreon-Regular", size: 20))
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                        .focused($zipFocused)
                                }
                            }
                            .padding(.horizontal)

                            Button("Save Changes") {
                                store.updateCurrentUser(firstName: store.currentUser?.firstName ?? "",
                                                        lastName: store.currentUser?.lastName ?? "",
                                                        zipCode: zipCode)
                                zipFocused = false
                            }
                            .font(.custom("Kreon-Regular", size: 17))
                            .buttonStyle(GreenButtonStyle())
                            .padding(.horizontal)
                            .opacity(hasChanges ? 1 : 0.4)
                            .disabled(!hasChanges)
                        }

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
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded { zipFocused = false })
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Account Settings")
                        .font(.custom("Kreon-Bold", size: 40))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { zipFocused = false }
                        .font(.custom("Kreon-Regular", size: 16))
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
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet().environment(store)
        }
    }

    @ViewBuilder
    private func readOnlyField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Kreon-Regular", size: 13).weight(.medium))
                .foregroundColor(.secondary)
            HStack {
                Text(value)
                    .font(.custom("Kreon-Regular", size: 20))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(uiColor: .systemFill))
            )
        }
    }

    private func syncFromStore() {
        zipCode = store.currentUser?.zipCode ?? ""
        loaded  = true
    }
}

// MARK: - Change Password Sheet

struct ChangePasswordSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword     = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: PasswordField?

    enum PasswordField { case current, new, confirm }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                secureField(label: "Current Password", text: $currentPassword, field: .current)
                secureField(label: "New Password",     text: $newPassword,     field: .new)
                secureField(label: "Confirm Password", text: $confirmPassword,  field: .confirm)

                if let error = errorMessage {
                    Text(error)
                        .font(.custom("Kreon-Regular", size: 14))
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { attemptChange() }
                        .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .font(.custom("Kreon-Regular", size: 16))
                }
            }
            .onAppear { focusedField = .current }
        }
        .presentationDetents([.height(310)])
    }

    @ViewBuilder
    private func secureField(label: String, text: Binding<String>, field: PasswordField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Kreon-Regular", size: 13).weight(.medium))
                .foregroundColor(.secondary)
            SecureField("", text: text)
                .font(.custom("Kreon-Regular", size: 18))
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: field)
                .onSubmit {
                    switch field {
                    case .current: focusedField = .new
                    case .new:     focusedField = .confirm
                    case .confirm: attemptChange()
                    }
                }
        }
    }

    private func attemptChange() {
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords don't match."
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        let success = store.changePassword(current: currentPassword, new: newPassword)
        if success {
            dismiss()
        } else {
            errorMessage = "Current password is incorrect."
            currentPassword = ""
            focusedField = .current
        }
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
