import SwiftUI
import SwiftData

struct TastingFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wine.name) private var wines: [Wine]

    /// Degustação sendo editada (nil = nova).
    let tasting: Tasting?
    /// Vinho já definido (vindo da tela do vinho).
    let presetWine: Wine?

    @State private var selectedWine: Wine?
    @State private var date: Date
    @State private var rating: Int
    @State private var priceText: String
    @State private var place: String
    @State private var notes: String
    @State private var consumeBottle: Bool

    init(wine: Wine? = nil, tasting: Tasting? = nil, consumeBottle: Bool = false) {
        self.tasting = tasting
        self.presetWine = wine ?? tasting?.wine
        _selectedWine = State(initialValue: wine ?? tasting?.wine)
        _date = State(initialValue: tasting?.date ?? .now)
        _rating = State(initialValue: tasting?.rating ?? 0)
        _priceText = State(initialValue: Fmt.priceText(tasting?.price))
        _place = State(initialValue: tasting?.place ?? "")
        _notes = State(initialValue: tasting?.notes ?? "")
        _consumeBottle = State(initialValue: consumeBottle)
    }

    private var isNew: Bool { tasting == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vinho") {
                    if let wine = presetWine {
                        HStack(spacing: 12) {
                            WineThumbnail(wine: wine, size: 40)
                            VStack(alignment: .leading) {
                                Text(wine.displayName).font(.headline)
                                if !wine.subtitle.isEmpty {
                                    Text(wine.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if wines.isEmpty {
                        Text("Cadastre um vinho na Adega primeiro.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Vinho", selection: $selectedWine) {
                            Text("Escolha…").tag(Wine?.none)
                            ForEach(wines) { wine in
                                Text(wine.displayName).tag(Optional(wine))
                            }
                        }
                    }

                    if isNew, let wine = selectedWine, wine.bottles > 0 {
                        Toggle(isOn: $consumeBottle) {
                            VStack(alignment: .leading) {
                                Text("Tirar uma garrafa da adega")
                                Text("Restam \(wine.bottles)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Nota") {
                    HStack {
                        Spacer()
                        StarRatingView(rating: $rating)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section("Detalhes") {
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    TextField("Onde (casa, restaurante…)", text: $place)
                    TextField("Preço pago (R$)", text: $priceText)
                        .keyboardType(.decimalPad)
                }

                Section("Comentários") {
                    TextField("Aromas, sabor, com o que harmonizou…", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                if let tasting {
                    Section {
                        Button("Apagar degustação", role: .destructive) {
                            context.delete(tasting)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Nova degustação" : "Degustação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(selectedWine == nil)
                }
            }
        }
    }

    private func save() {
        guard let wine = selectedWine else { return }
        let target: Tasting
        if let tasting {
            target = tasting
        } else {
            target = Tasting()
            context.insert(target)
            target.wine = wine
            if consumeBottle, wine.bottles > 0 {
                wine.bottles -= 1
            }
        }
        target.date = date
        target.rating = rating
        target.price = Fmt.parsePrice(priceText)
        target.place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
    }
}
