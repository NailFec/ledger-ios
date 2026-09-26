import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import SwiftUI

@Observable
@MainActor
final class AuthController {
    var email = ""
    var password = ""
    var isBusy = false
    var message: String?
    var isSignUp = false

    private var currentNonce: String?

    func validate() -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            return Copy.AuthErrors.invalidEmail
        }
        guard password.count >= 8 else {
            return Copy.AuthErrors.shortPassword
        }
        return nil
    }

    func submit(client: SupabaseClient) async {
        if let error = validate() {
            message = error
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            if isSignUp {
                _ = try await client.auth.signUp(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                message = Copy.AuthErrors.confirmEmail
            } else {
                _ = try await client.auth.signIn(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                message = nil
            }
        } catch {
            message = isSignUp ? error.localizedDescription : Copy.AuthErrors.badCredentials
        }
    }

    func signInWithGoogle(client: SupabaseClient) async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "ledger://auth-callback")
            )
        } catch {
            message = error.localizedDescription
        }
    }

    func prepareAppleNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleApple(result: Result<ASAuthorization, Error>, client: SupabaseClient) async {
        switch result {
        case .failure(let error):
            message = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                message = "Sign in with Apple failed."
                return
            }
            isBusy = true
            defer { isBusy = false }
            do {
                _ = try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )
                message = nil
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce.")
                }
                return random
            }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
