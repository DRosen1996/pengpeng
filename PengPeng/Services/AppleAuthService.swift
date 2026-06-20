import AuthenticationServices
import Foundation

enum AppleAuthError: LocalizedError {
    case cancelled
    case missingIdentityToken
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .cancelled:
            nil
        case .missingIdentityToken:
            "Apple 登录凭证无效"
        case .invalidCredential:
            "无法读取 Apple 登录信息"
        }
    }
}

struct AppleAuthResult {
    let identityToken: String
    let fullName: String?
}

enum AppleAuthService {
    static func parse(_ credential: ASAuthorizationAppleIDCredential) throws -> AppleAuthResult {
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleAuthError.missingIdentityToken
        }
        return AppleAuthResult(
            identityToken: identityToken,
            fullName: formatFullName(credential.fullName)
        )
    }

    static func isCancelled(_ error: Error) -> Bool {
        (error as? ASAuthorizationError)?.code == .canceled
    }

    private static func formatFullName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatted = PersonNameComponentsFormatter().string(from: components)
        return formatted.isEmpty ? nil : formatted
    }
}
