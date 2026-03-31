import SwiftUI

struct WelcomeView: View {
    @Environment(SupabaseService.self) private var supabaseService

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var confirmationMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Theme.GrainOverlay()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    rings
                        .padding(.bottom, 32)

                    Text("Daily Rings")
                        .font(Theme.mono(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("sleep · exercise · nutrition · productivity")
                        .font(Theme.mono(.caption))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 8)

                    Spacer().frame(height: 48)

                    authForm
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 60)
                }
                .frame(minHeight: UIScreen.main.bounds.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.light)
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Ring Preview

    private var rings: some View {
        ZStack {
            ForEach(Array(AppConstants.Ring.displayOrderOuterToInner.enumerated()), id: \.element) { index, ring in
                let size = 140.0 - Double(index) * 28
                Circle()
                    .stroke(
                        Theme.ringColor(for: ring).opacity(0.7),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: size, height: size)
            }
        }
    }

    // MARK: - Auth Form

    private var authForm: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.mono(.caption))
                    .foregroundStyle(Theme.exercise)
                    .multilineTextAlignment(.center)
            }

            if let confirmationMessage {
                Text(confirmationMessage)
                    .font(Theme.mono(.caption))
                    .foregroundStyle(Theme.nutrition)
                    .multilineTextAlignment(.center)
            }

            TextField("Email", text: $email)
                .font(Theme.mono(.body))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .email)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.surfaceSecondary)
                )
                .foregroundStyle(Theme.textPrimary)

            SecureField("Password", text: $password)
                .font(Theme.mono(.body))
                .textContentType(isSignUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.surfaceSecondary)
                )
                .foregroundStyle(Theme.textPrimary)

            Button {
                focusedField = nil
                Task { await handleAuth() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(Theme.mono(.body, weight: .semibold))
                    }
                }
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(Theme.textPrimary)
                )
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUp.toggle()
                    errorMessage = nil
                    confirmationMessage = nil
                }
            } label: {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(Theme.mono(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text("Your data syncs securely via Supabase")
                .font(Theme.mono(.caption2))
                .foregroundStyle(Theme.textQuaternary)
                .padding(.top, 8)
        }
    }

    // MARK: - Auth Action

    private func handleAuth() async {
        isLoading = true
        errorMessage = nil
        confirmationMessage = nil
        defer { isLoading = false }

        do {
            if isSignUp {
                try await supabaseService.signUp(email: email, password: password)
                confirmationMessage = "Check your email to confirm your account."
            } else {
                try await supabaseService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
