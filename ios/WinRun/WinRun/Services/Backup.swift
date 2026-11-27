import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Formato do arquivo (JSON)

nonisolated struct BackupArquivo: Codable, Sendable {
    var app: String
    var versao: Int
    var exportadoEm: Date
    var vinhos: [VinhoBackup]
}

nonisolated struct DegustacaoBackup: Codable, Sendable {
    var date: Date
    var rating: Int
    var notes: String
    var price: Double?
    var place: String
}

nonisolated struct VinhoBackup: Codable, Sendable {
    var name: String
    var producer: String
    var vintage: Int?
    var typeRaw: String
    var grape: String
    var country: String
    var region: String
    var bottles: Int
    var notes: String
    var photo: Data?          // JPEG; o JSONEncoder grava em base64
    var createdAt: Date
    var classification: String
    var alcohol: String
    var aging: String
    var tastingNotes: String
    var pairing: String
    var servingTemp: String
    var cellaring: String
    var ratings: String
    var about: String
    var sources: [String]
    var priceBRL: Double?
    var priceSummary: String
    var reviews: [ExpertReview]
    var researchedAt: Date?
    var degustacoes: [DegustacaoBackup]

    /// Vinho "igual" = mesmo nome, produtor e safra (para não duplicar ao juntar).
    var chave: String { Backup.chave(name: name, producer: producer, vintage: vintage) }
}

// MARK: - Exportar / importar

enum Backup {
    nonisolated static func chave(name: String, producer: String, vintage: Int?) -> String {
        let limpar: (String) -> String = { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        return "\(limpar(name))|\(limpar(producer))|\(vintage.map(String.init) ?? "")"
    }

    static func montar(_ wines: [Wine]) -> BackupArquivo {
        BackupArquivo(app: "WinRun", versao: 1, exportadoEm: .now, vinhos: wines.map { w in
            VinhoBackup(
                name: w.name, producer: w.producer, vintage: w.vintage, typeRaw: w.typeRaw,
                grape: w.grape, country: w.country, region: w.region, bottles: w.bottles, notes: w.notes,
                photo: w.photo, createdAt: w.createdAt,
                classification: w.classification, alcohol: w.alcohol, aging: w.aging,
                tastingNotes: w.tastingNotes, pairing: w.pairing, servingTemp: w.servingTemp,
                cellaring: w.cellaring, ratings: w.ratings, about: w.about, sources: w.sources,
                priceBRL: w.priceBRL, priceSummary: w.priceSummary, reviews: w.reviews, researchedAt: w.researchedAt,
                degustacoes: w.tastings.sorted { $0.date < $1.date }.map {
                    DegustacaoBackup(date: $0.date, rating: $0.rating, notes: $0.notes, price: $0.price, place: $0.place)
                }
            )
        })
    }

    nonisolated static func codificar(_ backup: BackupArquivo) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    nonisolated static func decodificar(_ dados: Data) throws -> BackupArquivo {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupArquivo.self, from: dados)
        guard backup.app == "WinRun" else { throw ErroBackup.arquivoInvalido }
        return backup
    }

    /// Junta o backup com a adega atual (pulando vinhos que já existem) ou substitui tudo.
    static func importar(_ backup: BackupArquivo, em context: ModelContext,
                         existentes: [Wine], substituir: Bool) throws -> (novos: Int, pulados: Int) {
        var chaves = Set<String>()
        if substituir {
            existentes.forEach { context.delete($0) }   // apaga as degustações junto (cascade)
        } else {
            chaves = Set(existentes.map { chave(name: $0.name, producer: $0.producer, vintage: $0.vintage) })
        }

        var novos = 0, pulados = 0
        for v in backup.vinhos {
            guard !chaves.contains(v.chave) else { pulados += 1; continue }
            chaves.insert(v.chave)

            let w = Wine(name: v.name, producer: v.producer, vintage: v.vintage, grape: v.grape,
                         country: v.country, region: v.region, bottles: v.bottles)
            context.insert(w)
            w.typeRaw = v.typeRaw
            w.notes = v.notes
            w.photo = v.photo
            w.createdAt = v.createdAt
            w.classification = v.classification
            w.alcohol = v.alcohol
            w.aging = v.aging
            w.tastingNotes = v.tastingNotes
            w.pairing = v.pairing
            w.servingTemp = v.servingTemp
            w.cellaring = v.cellaring
            w.ratings = v.ratings
            w.about = v.about
            w.sources = v.sources
            w.priceBRL = v.priceBRL
            w.priceSummary = v.priceSummary
            w.reviews = v.reviews
            w.researchedAt = v.researchedAt

            for d in v.degustacoes {
                let t = Tasting(date: d.date, rating: d.rating, notes: d.notes, price: d.price, place: d.place)
                context.insert(t)
                t.wine = w
            }
            novos += 1
        }
        try context.save()
        return (novos, pulados)
    }
}

enum ErroBackup: LocalizedError {
    case arquivoInvalido

    var errorDescription: String? {
        switch self {
        case .arquivoInvalido: "Esse arquivo não é um backup do WinRun."
        }
    }
}

// MARK: - Documento para o "Salvar em Arquivos"

nonisolated struct BackupDocumento: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var dados: Data

    init(dados: Data) { self.dados = dados }

    init(configuration: ReadConfiguration) throws {
        dados = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: dados)
    }
}
