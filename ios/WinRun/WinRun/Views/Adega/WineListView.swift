import SwiftUI
import SwiftData

struct WineListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Wine.name) private var wines: [Wine]

    @State private var search = ""
    @State private var typeFilter: WineType?
    @State private var onlyInStock = false
    @State private var showingNew = false
    @State private var showingAjustes = false

    private var filtered: [Wine] {
        wines.filter { wine in
            (typeFilter == nil || wine.wineType == typeFilter)
                && (!onlyInStock || wine.bottles > 0)
                && wine.matches(search)
        }
    }

    private var totalBottles: Int { wines.reduce(0) { $0 + $1.bottles } }

    var body: some View {
        NavigationStack {
            Group {
                if wines.isEmpty {
                    ContentUnavailableView {
                        Label("Adega vazia", systemImage: "wineglass")
                    } description: {
                        Text("Adicione seu primeiro vinho para começar.")
                    } actions: {
                        Button("Adicionar vinho") { showingNew = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(filtered) { wine in
                            NavigationLink(value: wine) {
                                WineRow(wine: wine)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .overlay {
                        if filtered.isEmpty {
                            ContentUnavailableView.search(text: search)
                        }
                    }
                }
            }
            .navigationTitle("Adega")
            .navigationSubtitle(wines.isEmpty ? "" : "\(totalBottles) garrafa\(totalBottles == 1 ? "" : "s") · \(wines.count) rótulo\(wines.count == 1 ? "" : "s")")
            .navigationDestination(for: Wine.self) { WineDetailView(wine: $0) }
            .searchable(text: $search, prompt: "Nome, produtor, uva, região")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ajustes", systemImage: "gearshape") { showingAjustes = true }
                }
                ToolbarItem(placement: .topBarLeading) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Novo vinho", systemImage: "plus") { showingNew = true }
                }
            }
            .sheet(isPresented: $showingNew) {
                WineFormView(wine: nil)
            }
            .sheet(isPresented: $showingAjustes) {
                AjustesView()
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Tipo", selection: $typeFilter) {
                Text("Todos os tipos").tag(WineType?.none)
                ForEach(WineType.allCases) { type in
                    Text(type.label).tag(Optional(type))
                }
            }
            Toggle("Só com garrafas", isOn: $onlyInStock)
        } label: {
            Label("Filtrar",
                  systemImage: (typeFilter != nil || onlyInStock)
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
        }
    }

    private func delete(at offsets: IndexSet) {
        let items = filtered
        for index in offsets {
            context.delete(items[index])
        }
    }
}

struct WineRow: View {
    let wine: Wine

    var body: some View {
        HStack(spacing: 12) {
            WineThumbnail(wine: wine, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(wine.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if !wine.subtitle.isEmpty {
                    Text(wine.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    WineTypeBadge(type: wine.wineType)
                    if let avg = wine.averageRating {
                        StarsLabel(rating: avg, size: 10)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(spacing: 0) {
                Text("\(wine.bottles)")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(wine.bottles > 0 ? .primary : .tertiary)
                Text(wine.bottles == 1 ? "garrafa" : "garrafas")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
