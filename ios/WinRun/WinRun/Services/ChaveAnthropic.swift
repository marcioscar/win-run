import Foundation
import Security

/// Chave da API da Anthropic de quem usa o app. Fica só no Keychain deste iPhone.
nonisolated enum ChaveAnthropic {
    private static let servico = "com.marcioscar.winrun"
    private static let conta = "anthropic-api-key"

    static var valor: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: servico,
                kSecAttrAccount as String: conta,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var resultado: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &resultado) == errSecSuccess,
                  let dados = resultado as? Data else { return nil }
            return String(data: dados, encoding: .utf8)
        }
        set {
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: servico,
                kSecAttrAccount as String: conta,
            ]
            SecItemDelete(base as CFDictionary)
            guard let nova = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !nova.isEmpty else { return }
            var item = base
            item[kSecValueData as String] = Data(nova.utf8)
            // só neste aparelho, sem ir para o backup do iCloud
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    static var configurada: Bool { !(valor ?? "").isEmpty }
}
