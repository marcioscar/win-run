import Foundation
import SwiftData

enum WineType: String, CaseIterable, Identifiable, Codable {
    case tinto, branco, rose, espumante, sobremesa, fortificado

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tinto: "Tinto"
        case .branco: "Branco"
        case .rose: "Rosé"
        case .espumante: "Espumante"
        case .sobremesa: "Sobremesa"
        case .fortificado: "Fortificado"
        }
    }
}

@Model
final class Wine {
    var name: String = ""
    var producer: String = ""
    var vintage: Int?
    var typeRaw: String = WineType.tinto.rawValue
    var grape: String = ""
    var country: String = ""
    var region: String = ""
    var bottles: Int = 0
    var notes: String = ""
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Tasting.wine)
    var tastings: [Tasting] = []

    init(name: String, producer: String = "", vintage: Int? = nil, wineType: WineType = .tinto,
         grape: String = "", country: String = "", region: String = "", bottles: Int = 1) {
        self.name = name
        self.producer = producer
        self.vintage = vintage
        self.typeRaw = wineType.rawValue
        self.grape = grape
        self.country = country
        self.region = region
        self.bottles = bottles
        self.createdAt = .now
    }

    var wineType: WineType {
        get { WineType(rawValue: typeRaw) ?? .tinto }
        set { typeRaw = newValue.rawValue }
    }

    /// "Nome 2019"
    var displayName: String {
        if let vintage { return "\(name) \(vintage)" }
        return name
    }

    /// "Produtor · Região, País"
    var subtitle: String {
        let origin = [region, country].filter { !$0.isEmpty }.joined(separator: ", ")
        return [producer, origin].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var averageRating: Double? {
        guard !tastings.isEmpty else { return nil }
        return Double(tastings.map(\.rating).reduce(0, +)) / Double(tastings.count)
    }

    func matches(_ search: String) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return [name, producer, grape, country, region, vintage.map(String.init) ?? ""]
            .contains { $0.localizedStandardContains(q) }
    }
}

@Model
final class Tasting {
    var date: Date = Date.now
    var rating: Int = 0
    var notes: String = ""
    var price: Double?
    var place: String = ""
    var wine: Wine?

    init(date: Date = .now, rating: Int = 0, notes: String = "", price: Double? = nil, place: String = "") {
        self.date = date
        self.rating = rating
        self.notes = notes
        self.price = price
        self.place = place
    }
}
