import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Bindable var session: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("碰碰")
                    .font(.system(size: 40, weight: .bold))
                Text("登录后查看附近同项目运动者")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 24)
            .disabled(isLoading)

            if isLoading {
                ProgressView("登录中…")
            }

            if let error = session.lastError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            #if DEBUG
            debugEmailLoginSection
            #endif

            Spacer()
        }
        .background(AppTheme.background)
    }

    #if DEBUG
    private var debugEmailLoginSection: some View {
        VStack(spacing: 12) {
            Text("开发调试")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)

            VStack(spacing: 12) {
                TextField("邮箱", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                SecureField("密码", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 24)

            PrimaryButton(title: isLoading ? "登录中…" : "邮箱登录") {
                Task { await submitEmailLogin() }
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding(.horizontal, 24)

            Text("使用 PocketBase 后台创建的测试账号")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }
    #endif

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                session.lastError = AppleAuthError.invalidCredential.localizedDescription
                return
            }

            isLoading = true
            defer { isLoading = false }

            do {
                let authResult = try AppleAuthService.parse(credential)
                _ = await session.loginWithApple(
                    identityToken: authResult.identityToken,
                    fullName: authResult.fullName
                )
            } catch {
                session.lastError = error.localizedDescription
            }

        case .failure(let error):
            guard !AppleAuthService.isCancelled(error) else { return }
            session.lastError = error.localizedDescription
        }
    }

    #if DEBUG
    private func submitEmailLogin() async {
        isLoading = true
        defer { isLoading = false }
        _ = await session.login(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }
    #endif
}

#Preview {
    LoginView(session: AppSession())
}
