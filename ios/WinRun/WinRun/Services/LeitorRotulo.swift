import Foundation

/// Ficha do vinho devolvida pela IA (saída estruturada — ver `LeitorRotulo.schema`).
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
    let precoMedioBRL: Double?
    let precoResumo: String?
    let avaliacoes: [Avaliacao]?

    var reviews: [ExpertReview] {
        (avaliacoes ?? []).map { ExpertReview(critic: $0.critico, score: $0.nota, comment: $0.comentario) }
    }
}

nonisolated enum LeitorRotuloErro: LocalizedError {
    case naoEhVinho

    var errorDescription: String? {
        switch self {
        case .naoEhVinho: "A foto não parece ser de um vinho."
        }
    }
}

/// Lê rótulos e pesquisa vinhos com o Claude (direto na API da Anthropic, com a chave de quem usa o app).
nonisolated enum LeitorRotulo {
    /// Foto do rótulo → o Claude lê e pesquisa ficha, preços e críticas na web (~30–60 s).
    static func ler(jpeg: Data) async throws -> RotuloLido {
        let conteudo: [[String: Any]] = [
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
            ["type": "text", "text": promptPesquisa],
        ]
        return try await executar(conteudo: conteudo, pesquisar: true)
    }

    /// Vinho já cadastrado (sem foto) → pesquisa ficha, preços e avaliações pelo nome.
    static func pesquisar(nome: String, produtor: String, safra: Int?) async throws -> RotuloLido {
        let conteudo: [[String: Any]] = [
            ["type": "text", "text": promptPorNome(nome: nome, produtor: produtor, safra: safra)],
        ]
        return try await executar(conteudo: conteudo, pesquisar: true)
    }

    private static func executar(conteudo: [[String: Any]], pesquisar: Bool) async throws -> RotuloLido {
        let dados = try await AnthropicAPI.gerarJSON(
            conteudo: conteudo,
            schema: schema,
            esforco: pesquisar ? "medium" : "low",
            ferramentas: pesquisar ? [buscaWeb] : nil
        )
        let rotulo = try JSONDecoder().decode(RotuloLido.self, from: dados)
        guard rotulo.ehVinho else { throw LeitorRotuloErro.naoEhVinho }
        return rotulo
    }

    // MARK: - Ferramenta de busca

    /// Busca "a partir do Brasil": sem isso os resultados vêm dos EUA e quase não aparecem lojas brasileiras.
    private static let buscaWeb: [String: Any] = [
        "type": "web_search_20260209",
        "name": "web_search",
        "max_uses": 8,
        "user_location": [
            "type": "approximate", "country": "BR", "region": "São Paulo",
            "city": "São Paulo", "timezone": "America/Sao_Paulo",
        ],
    ]

    // MARK: - Instruções

    private static let comoPesquisar = """
    Como fazer:
    1. Pesquise o vinho (nome + produtor + safra) para a ficha: prefira o site do produtor, fichas técnicas e importadoras. Se a safra exata não tiver informação, use a do vinho em geral e não invente números da safra.
    2. Preço no Brasil: faça pelo menos duas buscas em português, como um brasileiro faria — "<nome> <produtor> preço" e "<nome> 750ml comprar Brasil" — e use as lojas brasileiras que aparecerem (Wine, Evino, Grand Cru, Mistral, Divvino, Amazon.com.br, empórios e importadoras…). Lojas brasileiras quase nunca dizem a safra: aceite o preço do rótulo atual à venda e diga isso no resumo. Cuidado para não misturar com outro vinho da mesma vinícola (ex.: "D.V. Catena" não é "Catena Malbec"). Calcule precoMedioBRL com os preços de garrafa 750 ml encontrados (ignore kits, caixas, magnum e preços de clube). Em precoResumo, dê a faixa com as lojas (ex.: "R$ 150–250: Amazon R$ 150, Família Scopel R$ 209, Boccati R$ 220"); se não achar nada no Brasil, dê o preço lá fora (euro ou dólar) e deixe precoMedioBRL null.
    3. Avaliações: procure notas de críticos para a safra (Wine Enthusiast, James Suckling, Decanter, Robert Parker / Wine Advocate, Wine Spectator, Tim Atkin, Guía Peñín, Descorchados, Jancis Robinson) e a média do Vivino. Só inclua notas que você viu na pesquisa; diga a safra no comentário se for de outra safra. Em "pontuacoes", faça o resumo de uma linha.
    4. Campo sem informação confiável fica vazio — vazio é melhor que palpite errado.
    5. Escreva tudo em português do Brasil, de forma curta e útil para quem vai abrir ou comprar a garrafa.
    6. Em "fontes", coloque as URLs que você realmente usou.
    """

    private static let promptPesquisa = """
    Leia o rótulo de vinho desta foto e depois pesquise esse vinho na web para montar uma ficha completa, com preços e avaliações de especialistas.

    Primeiro identifique no rótulo o nome, o produtor e a safra. O produtor às vezes aparece pequeno ou só no contrarrótulo — a pesquisa resolve isso.

    \(comoPesquisar)

    Se a foto não for de um vinho, não pesquise: marque ehVinho como false e deixe os outros campos vazios (tipo "tinto", safra null, avaliacoes [], fontes []).
    """

    private static func promptPorNome(nome: String, produtor: String, safra: Int?) -> String {
        """
        Pesquise na web este vinho e monte a ficha completa, com preços e avaliações de especialistas.

        Vinho: \(nome)
        Produtor: \(produtor.isEmpty ? "(não informado — descubra na pesquisa)" : produtor)
        Safra: \(safra.map(String.init) ?? "(não informada)")

        \(comoPesquisar)

        Marque ehVinho como true. Se não encontrar esse vinho, devolva só o que foi informado acima e deixe o resto vazio.
        """
    }

    // MARK: - Formato da resposta (JSON Schema)

    private static let schema: [String: Any] = {
        let json = #"""
        {
          "type": "object",
          "additionalProperties": false,
          "required": ["ehVinho", "nome", "produtor", "safra", "tipo", "uva", "pais", "regiao", "classificacao",
                       "teorAlcoolico", "amadurecimento", "notasDegustacao", "harmonizacao", "temperaturaServico",
                       "potencialGuarda", "pontuacoes", "sobre", "precoMedioBRL", "precoResumo", "avaliacoes", "fontes"],
          "properties": {
            "ehVinho": { "type": "boolean", "description": "true se a foto mostra o rótulo ou a garrafa de um vinho" },
            "nome": { "type": "string", "description": "nome do vinho, sem o produtor e sem a safra (ex.: \"Royal Gran Reserva\")" },
            "produtor": { "type": "string", "description": "vinícola / bodega / produtor (ex.: \"Bodegas Franco-Españolas\")" },
            "safra": { "anyOf": [{ "type": "integer" }, { "type": "null" }], "description": "ano da safra; null se não há (NV)" },
            "tipo": { "type": "string", "enum": ["tinto", "branco", "rose", "espumante", "sobremesa", "fortificado"] },
            "uva": { "type": "string", "description": "uva(s) e, se souber, a proporção (ex.: \"Tempranillo 90%, Graciano 10%\")" },
            "pais": { "type": "string", "description": "país, em português" },
            "regiao": { "type": "string", "description": "região e denominação de origem (ex.: \"Rioja (D.O.Ca.)\")" },
            "classificacao": { "type": "string", "description": "classificação oficial ou de envelhecimento (Crianza, Reserva, Gran Reserva, DOCG, Grand Cru…); vazio se não houver" },
            "teorAlcoolico": { "type": "string", "description": "ex.: \"14% vol\"" },
            "amadurecimento": { "type": "string", "description": "tempo e tipo de barrica / garrafa (ex.: \"36 meses em carvalho francês e americano + 24 meses em garrafa\")" },
            "notasDegustacao": { "type": "string", "description": "visual, aroma e boca em 1–3 frases" },
            "harmonizacao": { "type": "string", "description": "pratos que combinam, em poucas palavras" },
            "temperaturaServico": { "type": "string", "description": "ex.: \"16–18 °C\"" },
            "potencialGuarda": { "type": "string", "description": "até quando beber (ex.: \"beber até 2035\")" },
            "pontuacoes": { "type": "string", "description": "resumo de uma linha das notas de críticos (ex.: \"93 pts Wine Enthusiast; 92 pts James Suckling\")" },
            "sobre": { "type": "string", "description": "2 a 4 frases sobre o produtor e este vinho: história, estilo, o que o torna especial" },
            "precoMedioBRL": { "anyOf": [{ "type": "number" }, { "type": "null" }], "description": "preço médio de UMA garrafa (750 ml) em lojas brasileiras, em reais; null se não achou loja no Brasil" },
            "precoResumo": { "type": "string", "description": "faixa de preço com as lojas (ex.: \"R$ 289–349 na Wine e na Grand Cru; cerca de €30 na Espanha\")" },
            "avaliacoes": {
              "type": "array",
              "description": "notas de críticos e publicações; prefira a safra exata",
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": ["critico", "nota", "comentario"],
                "properties": {
                  "critico": { "type": "string", "description": "crítico ou publicação (ex.: \"Wine Enthusiast\", \"Vivino (média dos usuários)\")" },
                  "nota": { "type": "string", "description": "ex.: \"93 pts\", \"4,1/5\"" },
                  "comentario": { "type": "string", "description": "trecho curto da avaliação traduzido para o português; vazio se não houver" }
                }
              }
            },
            "fontes": { "type": "array", "items": { "type": "string" }, "description": "URLs das páginas usadas na pesquisa (no máximo 6)" }
          }
        }
        """#
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }()
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
