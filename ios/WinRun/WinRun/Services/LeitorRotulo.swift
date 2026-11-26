import Foundation

/// Resposta do POST /api/ler-rotulo (backend marcioscar).
nonisolated struct RotuloLido: Decodable, Sendable {
    let ehVinho: Bool
    let nome: String
    let produtor: String
    let safra: Int?
    let tipo: String
    let uva: String
    let pais: String
    let regiao: String
    let observacoes: String
}

nonisolated enum LeitorRotuloErro: LocalizedError {
    case semToken
    case enderecoInvalido
    case servidor(String)
    case naoEhVinho

    var errorDescription: String? {
        switch self {
        case .semToken: "Configure o token em Ajustes para usar a IA."
        case .enderecoInvalido: "Endereço do servidor inválido (veja em Ajustes)."
        case .servidor(let msg): msg
        case .naoEhVinho: "A foto não parece ser de um vinho."
        }
    }
}

nonisolated enum LeitorRotulo {
    /// Envia a foto (JPEG) para o backend, que pergunta ao Claude o que está escrito no rótulo.
    static func ler(jpeg: Data) async throws -> RotuloLido {
        guard let token = Servidor.token, !token.isEmpty else { throw LeitorRotuloErro.semToken }
        guard let base = URL(string: Servidor.endereco),
              let url = URL(string: "/api/ler-rotulo", relativeTo: base) else {
            throw LeitorRotuloErro.enderecoInvalido
        }

        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "imagem": jpeg.base64EncodedString(),
            "mediaType": "image/jpeg",
        ])

        let (dados, resposta) = try await URLSession.shared.data(for: request)
        let status = (resposta as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            struct Erro: Decodable { let error: String }
            let mensagem = (try? JSONDecoder().decode(Erro.self, from: dados))?.error
            switch status {
            case 401: throw LeitorRotuloErro.servidor("Token recusado pelo servidor (veja em Ajustes).")
            case 404: throw LeitorRotuloErro.servidor("O servidor ainda não tem a leitura de rótulo (rota não encontrada).")
            default: throw LeitorRotuloErro.servidor(mensagem ?? "Erro \(status) no servidor.")
            }
        }

        let rotulo = try JSONDecoder().decode(RotuloLido.self, from: dados)
        guard rotulo.ehVinho else { throw LeitorRotuloErro.naoEhVinho }
        return rotulo
    }
}
