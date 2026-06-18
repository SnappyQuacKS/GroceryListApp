import SwiftUI

struct LoginView: View {
    @Environment(AppStore.self) private var store
    @State private var showingSignIn = false

    var body: some View {
        ZStack {
            LinedPaperBackground()

            VStack {
                Spacer()

                // Logo
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220)

                // Database connection status
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.serverStatus == .ok ? Color.green :
                              store.serverStatus == .syncing ? Color.orange : Color.red)
                        .frame(width: 8, height: 8)
                    Text(store.serverStatusText)
                        .font(.custom("Kreon-Regular", size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                Spacer()

                // Actions
                VStack(spacing: 14) {
                    Button("Continue as Guest") { store.continueAsGuest() }
                        .font(.custom("Kreon-Regular", size: 17))
                        .buttonStyle(OutlineButtonStyle())

                    Button("Sign In") { showingSignIn = true }
                        .font(.custom("Kreon-Regular", size: 17))
                        .buttonStyle(GreenButtonStyle())

                }
                .padding(.horizontal, 32)
                .padding(.bottom, 54)
            }
        }
        .sheet(isPresented: $showingSignIn) {
            SignInView().environment(store)
                .presentationDetents([.fraction(0.33)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Sign In / Create Account Sheet

struct SignInView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var errorMessage: String? = nil
    @State private var isLoading = false

    private var fieldsEmpty: Bool { email.isEmpty || password.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                    .font(.custom("Kreon-Regular", size: 16))

                SecureField("Password", text: $password)
                    .textContentType(isCreatingAccount ? .newPassword : .password)
                    .textFieldStyle(.roundedBorder)
                    .font(.custom("Kreon-Regular", size: 16))

                if let error = errorMessage {
                    Text(error)
                        .font(.custom("Kreon-Regular", size: 13))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(isCreatingAccount ? "Create Account" : "Sign In") {
                    isLoading = true
                    errorMessage = nil
                    Task {
                        let err = isCreatingAccount
                            ? await store.createAccount(email: email, password: password)
                            : await store.signIn(email: email, password: password)
                        isLoading = false
                        if let err {
                            errorMessage = err
                        } else {
                            dismiss()
                        }
                    }
                }
                .font(.custom("Kreon-Regular", size: 17))
                .buttonStyle(GreenButtonStyle())
                .disabled(fieldsEmpty || isLoading)
                .opacity(isLoading ? 0.7 : 1)

                Button(isCreatingAccount ? "Already have an account? Sign In" : "New here? Create Account") {
                    isCreatingAccount.toggle()
                    errorMessage = nil
                }
                .font(.custom("Kreon-Regular", size: 13))
                .foregroundColor(Color(red: 0.15, green: 0.55, blue: 0.38))

                Spacer()
            }
            .padding()
            .navigationTitle(isCreatingAccount ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isCreatingAccount ? "Create Account" : "Sign In")
                        .font(.custom("Kreon-Bold", size: 17))
                }
            }
        }
    }
}

// MARK: - Lined Paper Background

struct LinedPaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var showMargin: Bool = true

    private var paperColor: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.16, blue: 0.18)
            : Color(red: 0.98, green: 0.97, blue: 0.87)
    }

    private var lineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color(red: 0.38, green: 0.52, blue: 0.78).opacity(0.55)
    }

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paperColor))
            let spacing: CGFloat = 36
            var y = spacing
            while y < size.height + spacing {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 3)
                y += spacing
            }
            if showMargin {
                var margin = Path()
                margin.move(to: CGPoint(x: 54, y: 0))
                margin.addLine(to: CGPoint(x: 54, y: size.height))
                context.stroke(margin, with: .color(.init(red: 0.82, green: 0.32, blue: 0.32, opacity: 0.45)), lineWidth: 3)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Shared Button Styles

struct GreenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.15, green: 0.55, blue: 0.38))
            .foregroundColor(.white)
            .fontWeight(.medium)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .foregroundColor(Color(red: 0.15, green: 0.55, blue: 0.38))
            .fontWeight(.medium)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.15, green: 0.55, blue: 0.38), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
