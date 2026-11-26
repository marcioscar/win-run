import Foundation
import Security

/// Endereço do backend (site marcioscar) e token de acesso.
/// O token fica no Keychain; o endereço, nos Ajustes do app.
nonisolated enum Servidor {
    static let enderecoPadrao = "https://financeiro.marcioscar.com.br"
    private static let chaveEndereco = "enderecoServidor"
    private static let servico = "com.marcioscar.winrun"
    private static let contaToken = "api-token"

    static var endereco: String {
        get { UserDefaults.standard.string(forKey: chaveEndereco) ?? enderecoPadrao }
        set {
            let limpo = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(limpo.isEmpty ? enderecoPadrao : limpo, forKey: chaveEndereco)
        }
    }

    static var token: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: servico,
                kSecAttrAccount as String: contaToken,
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
                kSecAttrAccount as String: contaToken,
            ]
            SecItemDelete(base as CFDictionary)
            guard let novo = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !novo.isEmpty else { return }
            var item = base
            item[kSecValueData as String] = Data(novo.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    static var configurado: Bool { !(token ?? "").isEmpty }
}
