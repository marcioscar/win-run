import SwiftUI
import SwiftData

struct WineDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var wine: Wine

    @State private var showingEdit = false
    @State private var showingNewTasting = false
    @State private var openBottleOnTasting = false
    @State private var editingTasting: Tasting?
    @State private var confirmingDelete = false

    private var sortedTastings: [Tasting] {
        wine.tastings.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            Section("Adega") {
                Stepper(value: $wine.bottles, in: 0...999) {
                    HStack {
                        Text("Garrafas")
                        Spacer()
                        Text("\(wine.bottles)")
                            .font(.body.weight(.semibold).monospacedDigit())
                    }
                }
                Button {
                    openBottleOnTasting = true
                    showingNewTasting = true
                } label: {
                    Label("Abrir uma garrafa", systemImage: "wineglass")
                }
                .disabled(wine.bottles == 0)
            }

            if hasDetails {
                Section("Detalhes") {
                    detailRow("Uva", wine.grape)
                    detailRow("País", wine.country)
                    detailRow("Região", wine.region)
                    detailRow("Classificação", wine.classification)
                    detailRow("Teor alcoólico", wine.alcohol)
                    detailRow("Temperatura", wine.servingTemp)
                    detailRow("Guarda", wine.cellaring)
                    if !wine.notes.isEmpty {
                        Text(wine.notes)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if hasFicha {
                Section("Ficha") {
                    fichaBlock("Amadurecimento", "clock", wine.aging)
                    fichaBlock("Notas de degustação", "nose", wine.tastingNotes)
                    fichaBlock("Harmonização", "fork.knife", wine.pairing)
                    fichaBlock("Pontuações", "rosette", wine.ratings)
                }
            }

            if !wine.about.isEmpty {
                Section("Sobre") {
                    Text(wine.about)
                        .font(.callout)
                }
            }

            if !wine.sources.isEmpty {
                Section("Fontes") {
                    ForEach(wine.sources, id: \.self) { fonte in
                        if let url = URL(string: fonte) {
                            Link(destination: url) {
                                Label(url.host() ?? fonte, systemImage: "link")
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            Section {
                if sortedTastings.isEmpty {
                    Text("Nenhuma degustação ainda.")
                        .foregroundStyle(.secondary)
                }
                ForEach(sortedTastings) { tasting in
                    Button {
                        editingTasting = tasting
                    } label: {
                        TastingSummaryRow(tasting: tasting)
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    let items = sortedTastings
                    offsets.forEach { context.delete(items[$0]) }
                }
                Button {
                    openBottleOnTasting = false
                    showingNewTasting = true
                } label: {
                    Label("Registrar degustação", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("Degustações")
                    Spacer()
                    if let avg = wine.averageRating {
                        StarsLabel(rating: avg, size: 11)
                        Text(String(format: "%.1f", avg))
                    }
                }
            }

            Section {
                Button("Apagar vinho", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(wine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Editar") { showingEdit = true }
        }
        .sheet(isPresented: $showingEdit) {
            WineFormView(wine: wine)
        }
        .sheet(isPresented: $showingNewTasting) {
            TastingFormView(wine: wine, consumeBottle: openBottleOnTasting)
        }
        .sheet(item: $editingTasting) { tasting in
            TastingFormView(tasting: tasting)
        }
        .confirmationDialog("Apagar \(wine.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Apagar vinho e degustações", role: .destructive) {
                context.delete(wine)
                dismiss()
            }
        } message: {
            Text("As degustações deste vinho também serão apagadas.")
        }
    }

    private var hasDetails: Bool {
        ![wine.grape, wine.country, wine.region, wine.notes,
          wine.classification, wine.alcohol, wine.servingTemp, wine.cellaring].allSatisfy(\.isEmpty)
    }

    private var hasFicha: Bool {
        ![wine.aging, wine.tastingNotes, wine.pairing, wine.ratings].allSatisfy(\.isEmpty)
    }

    @ViewBuilder
    private func fichaBlock(_ title: String, _ icon: String, _ value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(value)
                    .font(.callout)
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            if let data = wine.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                WineThumbnail(wine: wine, size: 110)
            }
            VStack(spacing: 4) {
                Text(wine.displayName)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if !wine.subtitle.isEmpty {
                    Text(wine.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                WineTypeBadge(type: wine.wineType)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// Linha usada dentro do detalhe do vinho (sem repetir o nome do vinho).
struct TastingSummaryRow: View {
    let tasting: Tasting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                StarsLabel(rating: Double(tasting.rating), size: 12)
                Spacer()
                Text(tasting.date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !tasting.notes.isEmpty {
                Text(tasting.notes)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            let extra = [tasting.place, tasting.price.map(Fmt.price) ?? ""].filter { !$0.isEmpty }
            if !extra.isEmpty {
                Text(extra.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
