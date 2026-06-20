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

            if let error = session.lastError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            PrimaryButton(title: isLoading ? "登录中…" : "登录") {
                Task { await submit() }
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding(.horizontal, 24)

            Text("使用 PocketBase 后台创建的测试账号")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.tertiaryText)

            Spacer()
        }
        .background(AppTheme.background)
    }

    private func submit() async {
        isLoading = true
        defer { isLoading = false }
        _ = await session.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
    }
}

#Preview {
    LoginView(session: AppSession())
}
