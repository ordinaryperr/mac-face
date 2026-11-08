import AuthenticationServices
import Foundation
import Security
import SwiftUI

@MainActor
final class AppleSession: ObservableObject {
    enum Phase: Equatable {
        case checking, signedOut, signedIn
    }

    @Published private(set) var phase: Phase = .checking
    @Published private(set) var isSigningIn = false
    @Published private(set) var message: String?
    private var requestState: String?

    let isConfigured: Bool = {
        guard let task = SecTaskCreateFromSelf(nil),
              let capability = SecTaskCopyValueForEntitlement(task, "com.apple.developer.applesignin" as CFString, nil) as? [String],
              let appID = SecTaskCopyValueForEntitlement(task, "com.apple.application-identifier" as CFString, nil) as? String,
              let bundleID = Bundle.main.bundleIdentifier else { return false }
        return capability.contains("Default") && appID.hasSuffix(".\(bundleID)")
    }()

    func restore() async {
        guard phase == .checking else { return }
        guard isConfigured else {
            phase = .signedOut
            return
        }

        do {
            guard let user = try readUser() else {
                phase = .signedOut
                return
            }

            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: user)
            switch state {
            case .authorized:
                phase = .signedIn
            case .revoked, .notFound, .transferred:
                try deleteUser()
                phase = .signedOut
            @unknown default:
                phase = .signedOut
                message = "Apple 로그인 상태를 확인하지 못했습니다. 다시 로그인해 주세요."
            }
        } catch {
            phase = .signedOut
            message = "Apple 로그인 상태를 확인하지 못했습니다. 다시 로그인해 주세요."
        }
    }

    func recheck() async {
        guard phase == .signedIn else { return }
        phase = .checking
        message = nil
        await restore()
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let state = UUID().uuidString
        request.state = state
        requestState = state
        isSigningIn = true
        message = nil
    }

    func complete(_ result: Result<ASAuthorization, Error>) {
        guard phase == .signedOut, let requestState else { return }
        self.requestState = nil
        isSigningIn = false

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  credential.state == requestState, !credential.user.isEmpty else {
                message = "Apple 로그인 응답을 확인하지 못했습니다. 다시 시도해 주세요."
                return
            }
            do {
                try saveUser(credential.user)
                phase = .signedIn
            } catch {
                message = "로그인 정보를 키체인에 저장하지 못했습니다. 다시 시도해 주세요."
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                message = "Apple 로그인을 완료하지 못했습니다. 시스템 설정의 Apple 계정과 앱 서명을 확인해 주세요."
            }
        }
    }

    func signOut() {
        do {
            try deleteUser()
            message = nil
            phase = .signedOut
        } catch {
            message = "키체인에서 로그인 정보를 지우지 못했습니다. 로그아웃을 다시 시도해 주세요."
        }
    }

    // Store only the system-provided user identifier for local session restoration.
    private var keychainItem: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Bundle.main.bundleIdentifier ?? "local.macface.app",
         kSecAttrAccount as String: "sign-in-with-apple",
         kSecUseDataProtectionKeychain as String: true]
    }

    private func readUser() throws -> String? {
        var query = keychainItem
        query[kSecReturnData as String] = true
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        try checkKeychain(status)
        guard let data = value as? Data, let user = String(data: data, encoding: .utf8), !user.isEmpty else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecDecode))
        }
        return user
    }

    private func saveUser(_ user: String) throws {
        let data = Data(user.utf8)
        let changes = [kSecValueData as String: data]
        let status = SecItemUpdate(keychainItem as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var item = keychainItem
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            try checkKeychain(SecItemAdd(item as CFDictionary, nil))
        } else {
            try checkKeychain(status)
        }
    }

    private func deleteUser() throws {
        let status = SecItemDelete(keychainItem as CFDictionary)
        if status != errSecItemNotFound { try checkKeychain(status) }
    }

    private func checkKeychain(_ status: OSStatus) throws {
        if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
