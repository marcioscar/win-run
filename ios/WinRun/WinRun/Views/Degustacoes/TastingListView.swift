import SwiftUI
import SwiftData

struct TastingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tasting.date, order: .reverse) private var tastings: [Tasting]

    @State private var showingNew = false
    @State private var editing: Tasting?
    @State private var search = ""

    private var filtered: [Tasting] {
        tastings.filter { tasting in
            search.isEmpty
                || (tasting.wine?.matches(search) ?? false)
                || tasting.place.localizedStandardContains(search)
                || tasting.notes.localizedStandardContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tastings.isEmpty {
                    ContentUnavailableView {
                        Label("Nenhuma degustação", systemImage: "list.star")
                    } description: {
                        Text("Registre o que você bebeu, a nota e o que achou.")
                    } actions: {
                        Button("Registrar degustação") { showingNew = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(filtered) { tasting in
                            Button {
                                editing = tasting
                            } label: {
                                TastingRow(tasting: tasting)
                            }
                            .tint(.primary)
                        }
                        .onDelete { offsets in
                            let items = filtered
                            offsets.forEach { context.delete(items[$0]) }
                        }
                    }
                    .overlay {
                        if filtered.isEmpty {
                            ContentUnavailableView.search(text: search)
                        }
                    }
                }
            }
            .navigationTitle("Degustações")
            .searchable(text: $search, prompt: "Vinho, lugar, comentário")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nova degustação", systemImage: "plus") { showingNew = true }
                }
            }
            .sheet(isPresented: $showingNew) {
                TastingFormView()
            }
            .sheet(item: $editing) { tasting in
                TastingFormView(tasting: tasting)
            }
        }
    }
}

struct TastingRow: View {
    let tasting: Tasting

    var body: some View {
        HStack(spacing: 12) {
            if let wine = tasting.wine {
                WineThumbnail(wine: wine, size: 48)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tasting.wine?.displayName ?? "Vinho removido")
                    .font(.headline)
                    .lineLimit(1)
                StarsLabel(rating: Double(tasting.rating), size: 11)
                let info = [
                    tasting.date.formatted(.dateTime.day().month(.abbreviated).year()),
                    tasting.place,
                ].filter { !$0.isEmpty }
                Text(info.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let price = tasting.price {
                Text(Fmt.price(price))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
