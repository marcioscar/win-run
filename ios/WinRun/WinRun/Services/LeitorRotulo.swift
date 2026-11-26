import Foundation

/// Resposta do POST /api/ler-rotulo (backend marcioscar).
nonisolated struct RotuloLido: Decodable, Sendable {
    nonisolated struct Avaliacao: Decodable, Sendable {
        let critico: String
        let nota: String
        let comentario: String
    }

    let ehVinho: Bool
    let nome: String
    let produtor: String
    let safra: Int?
    let tipo: String
    let uva: String
    let pais: String
    let regiao: String
    let classificacao: String
    let teorAlcoolico: String
    let amadurecimento: String
    let notasDegustacao: String
    let harmonizacao: String
    let temperaturaServico: String
    let potencialGuarda: String
    let pontuacoes: String
    let sobre: String
    let fontes: [String]
    // opcionais: versões antigas do servidor não mandam
    let precoMedioBRL: Double?
    let precoResumo: String?
    let avaliacoes: [Avaliacao]?

    var reviews: [ExpertReview] {
        (avaliacoes ?? []).map { ExpertReview(critic: $0.critico, score: $0.nota, comment: $0.comentario) }
    }
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
    /// Envia a foto (JPEG): o Claude lê o rótulo e pesquisa ficha, preços e críticas na web (~30–60 s).
    static func ler(jpeg: Data) async throws -> RotuloLido {
        try await enviar([
            "imagem": jpeg.base64EncodedString(),
            "mediaType": "image/jpeg",
            "pesquisar": true,
        ])
    }

    /// Pesquisa um vinho já cadastrado pelo nome (sem foto) — usado para atualizar preços e avaliações.
    static func pesquisar(nome: String, produtor: String, safra: Int?) async throws -> RotuloLido {
        var vinho: [String: Any] = ["nome": nome, "produtor": produtor]
        if let safra { vinho["safra"] = safra }
        return try await enviar(["vinho": vinho])
    }

    private static func enviar(_ corpo: [String: Any]) async throws -> RotuloLido {
        guard let token = Servidor.token, !token.isEmpty else { throw LeitorRotuloErro.semToken }
        guard let base = URL(string: Servidor.endereco),
              let url = URL(string: "/api/ler-rotulo", relativeTo: base) else {
            throw LeitorRotuloErro.enderecoInvalido
        }

        var request = URLRequest(url: url, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: corpo)

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

extension Wine {
    /// Aplica uma pesquisa a um vinho já salvo: completa só os campos vazios da ficha
    /// e sempre atualiza preço, avaliações e fontes (essas informações mudam com o tempo).
    func aplicarPesquisa(_ r: RotuloLido) {
        func preencher(_ campo: ReferenceWritableKeyPath<Wine, String>, _ valor: String) {
            if self[keyPath: campo].trimmingCharacters(in: .whitespaces).isEmpty, !valor.isEmpty {
                self[keyPath: campo] = valor
            }
        }
        preencher(\.producer, r.produtor)
        preencher(\.grape, r.uva)
        preencher(\.country, r.pais)
        preencher(\.region, r.regiao)
        preencher(\.classification, r.classificacao)
        preencher(\.alcohol, r.teorAlcoolico)
        preencher(\.aging, r.amadurecimento)
        preencher(\.tastingNotes, r.notasDegustacao)
        preencher(\.pairing, r.harmonizacao)
        preencher(\.servingTemp, r.temperaturaServico)
        preencher(\.cellaring, r.potencialGuarda)
        preencher(\.about, r.sobre)
        if vintage == nil { vintage = r.safra }

        if !r.pontuacoes.isEmpty { ratings = r.pontuacoes }
        priceBRL = r.precoMedioBRL
        priceSummary = r.precoResumo ?? ""
        if !r.reviews.isEmpty { reviews = r.reviews }
        if !r.fontes.isEmpty { sources = r.fontes }
        researchedAt = .now
    }
}
