import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Environment(AppModel.self) private var appModel
    @State private var controller = AuthController()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Copy.Settings.email, text: $controller.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $controller.password)
                        .textContentType(controller.isSignUp ? .newPassword : .password)
                }

                if let message = controller.message {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(controller.isSignUp ? Copy.Navigation.signUp : Copy.Navigation.signIn) {
                        Task {
                            guard let client = appModel.client else { return }
                            await controller.submit(client: client)
                        }
                    }
                    .disabled(controller.isBusy)

                    Button(controller.isSignUp ? "Have an account? Sign in" : "Need an account? Sign up") {
                        controller.isSignUp.toggle()
                        controller.message = nil
                    }
                }

                Section {
                    SignInWithAppleButton(.signIn) { request in
                        let hashed = controller.prepareAppleNonce()
                        request.requestedScopes = [.email]
                        request.nonce = hashed
                    } onCompletion: { result in
                        Task {
                            guard let client = appModel.client else { return }
                            await controller.handleApple(result: result, client: client)
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)

                    Button("Continue with Google") {
                        Task {
                            guard let client = appModel.client else { return }
                            await controller.signInWithGoogle(client: client)
                        }
                    }
                    .disabled(controller.isBusy)
                }
            }
            .navigationTitle(controller.isSignUp ? Copy.Navigation.signUp : Copy.Navigation.signIn)
        }
    }
}
