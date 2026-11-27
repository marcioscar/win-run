import Foundation

/// Chamada direta à API da Anthropic (Messages API, HTTP puro — não há SDK oficial para Swift).
/// Usa a chave de quem está usando o app (ChaveAnthropic).
nonisolated enum AnthropicAPI {
    static let modelo = "claude-sonnet-5-5"
    /// se o modelo recusar por engano, a própria API refaz o pedido neste modelo
    static let modeloReserva = "claude-sonnet-5"
    private static let urlMensagens = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let urlModelos = URL(string: "https://api.anthropic.com/v1/models?limit=1")!
    private static let maxContinuacoes = 4

    enum Erro: LocalizedError {
        case semChave
        case chaveInvalida
        case semCreditos
        case muitosPedidos
        case api(String)
        case respostaInesperada
        case recusou
        case incompleta

        var errorDescription: String? {
            switch self {
            case .semChave: "Coloque sua chave da API da Anthropic em Ajustes para usar a IA."
            case .chaveInvalida: "A chave da Anthropic foi recusada. Confira em Ajustes."
            case .semCreditos: "Sua conta da Anthropic está sem créditos. Compre créditos em platform.claude.com (Billing)."
            case .muitosPedidos: "Muitos pedidos seguidos ou API sobrecarregada; tente em instantes."
            case .api(let msg): "Erro da API da Anthropic: \(msg)"
            case .respostaInesperada: "Resposta inesperada da IA."
            case .recusou: "A IA não conseguiu responder a esse pedido."
            case .incompleta: "Resposta incompleta da IA, tente de novo."
            }
        }
    }

    // MARK: - Testar chave

    /// Confere se a chave é aceita (lista modelos — não gasta créditos).
    static func testarChave(_ chave: String) async throws {
        var request = URLRequest(url: urlModelos, timeoutInterval: 20)
        aplicarCabecalhos(&request, chave: chave)
        let (dados, resposta) = try await URLSession.shared.data(for: request)
        try verificar(resposta: resposta, dados: dados)
    }

    // MARK: - Mensagens

    /// Envia uma mensagem e devolve o texto final (o JSON da saída estruturada).
    /// Com busca na web, a API pode pausar o turno (`pause_turn`); nesse caso continuamos a conversa.
    static func gerarJSON(conteudo: [[String: Any]], schema: [String: Any], esforco: String,
                          ferramentas: [[String: Any]]?) async throws -> Data {
        guard let chave = ChaveAnthropic.valor, !chave.isEmpty else { throw Erro.semChave }

        var mensagens: [[String: Any]] = [["role": "user", "content": conteudo]]
        var json: [String: Any] = [:]

        for _ in 0...maxContinuacoes {
            var corpo: [String: Any] = [
                "model": modelo,
                "max_tokens": 16000,
                "fallbacks": [["model": modeloReserva]],
                "output_config": [
                    "effort": esforco,
                    "format": ["type": "json_schema", "schema": schema],
                ],
                "messages": mensagens,
            ]
            if let ferramentas { corpo["tools"] = ferramentas }

            var request = URLRequest(url: urlMensagens, timeoutInterval: 180)
            request.httpMethod = "POST"
            aplicarCabecalhos(&request, chave: chave)
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
            request.httpBody = try JSONSerialization.data(withJSONObject: corpo)

            let (dados, resposta) = try await URLSession.shared.data(for: request)
            try verificar(resposta: resposta, dados: dados)
            guard let obj = try JSONSerialization.jsonObject(with: dados) as? [String: Any] else {
                throw Erro.respostaInesperada
            }
            json = obj
            guard json["stop_reason"] as? String == "pause_turn" else { break }
            // devolve o que já veio e pede para continuar
            mensagens.append(["role": "assistant", "content": json["content"] ?? []])
        }

        switch json["stop_reason"] as? String {
        case "refusal": throw Erro.recusou
        case "max_tokens", "pause_turn": throw Erro.incompleta
        default: break
        }

        // com saída estruturada, o JSON é o último bloco de texto (depois das buscas)
        let blocos = json["content"] as? [[String: Any]] ?? []
        guard let texto = blocos.last(where: { $0["type"] as? String == "text" })?["text"] as? String else {
            throw Erro.respostaInesperada
        }
        return Data(texto.utf8)
    }

    // MARK: - Auxiliares

    private static func aplicarCabecalhos(_ request: inout URLRequest, chave: String) {
        request.setValue(chave, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
    }

    private static func verificar(resposta: URLResponse, dados: Data) throws {
        let status = (resposta as? HTTPURLResponse)?.statusCode ?? 0
        guard status != 200 else { return }

        struct Corpo: Decodable {
            struct Detalhe: Decodable { let type: String?; let message: String? }
            let error: Detalhe?
        }
        let mensagem = (try? JSONDecoder().decode(Corpo.self, from: dados))?.error?.message ?? "HTTP \(status)"

        switch status {
        case 401, 403: throw Erro.chaveInvalida
        case 429, 529: throw Erro.muitosPedidos
        default:
            if mensagem.localizedCaseInsensitiveContains("credit balance") { throw Erro.semCreditos }
            throw Erro.api(mensagem)
        }
    }
}
