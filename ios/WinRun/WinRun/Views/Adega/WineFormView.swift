import SwiftUI
import SwiftData
import PhotosUI

struct WineFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let wine: Wine?

    @State private var name: String
    @State private var producer: String
    @State private var vintageText: String
    @State private var wineType: WineType
    @State private var grape: String
    @State private var country: String
    @State private var region: String
    @State private var bottles: Int
    @State private var notes: String
    @State private var photo: Data?

    @State private var classification: String
    @State private var alcohol: String
    @State private var aging: String
    @State private var tastingNotes: String
    @State private var pairing: String
    @State private var servingTemp: String
    @State private var cellaring: String
    @State private var ratings: String
    @State private var about: String
    @State private var sources: [String]
    @State private var priceBRL: Double?
    @State private var priceSummary: String
    @State private var reviews: [ExpertReview]
    @State private var researchedAt: Date?

    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false

    @State private var lendoRotulo = false
    @State private var erroRotulo: String?
    @State private var rotuloPreenchido = false

    init(wine: Wine?) {
        self.wine = wine
        _name = State(initialValue: wine?.name ?? "")
        _producer = State(initialValue: wine?.producer ?? "")
        _vintageText = State(initialValue: wine?.vintage.map(String.init) ?? "")
        _wineType = State(initialValue: wine?.wineType ?? .tinto)
        _grape = State(initialValue: wine?.grape ?? "")
        _country = State(initialValue: wine?.country ?? "")
        _region = State(initialValue: wine?.region ?? "")
        _bottles = State(initialValue: wine?.bottles ?? 1)
        _notes = State(initialValue: wine?.notes ?? "")
        _photo = State(initialValue: wine?.photo)
        _classification = State(initialValue: wine?.classification ?? "")
        _alcohol = State(initialValue: wine?.alcohol ?? "")
        _aging = State(initialValue: wine?.aging ?? "")
        _tastingNotes = State(initialValue: wine?.tastingNotes ?? "")
        _pairing = State(initialValue: wine?.pairing ?? "")
        _servingTemp = State(initialValue: wine?.servingTemp ?? "")
        _cellaring = State(initialValue: wine?.cellaring ?? "")
        _ratings = State(initialValue: wine?.ratings ?? "")
        _about = State(initialValue: wine?.about ?? "")
        _sources = State(initialValue: wine?.sources ?? [])
        _priceBRL = State(initialValue: wine?.priceBRL)
        _priceSummary = State(initialValue: wine?.priceSummary ?? "")
        _reviews = State(initialValue: wine?.reviews ?? [])
        _researchedAt = State(initialValue: wine?.researchedAt)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section("Vinho") {
                    TextField("Nome", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Produtor / vinícola", text: $producer)
                        .textInputAutocapitalization(.words)
                    TextField("Safra (ex.: 2019)", text: $vintageText)
                        .keyboardType(.numberPad)
                    Picker("Tipo", selection: $wineType) {
                        ForEach(WineType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                }

                Section("Origem") {
                    TextField("Uva(s)", text: $grape)
                        .textInputAutocapitalization(.words)
                    TextField("País", text: $country)
                        .textInputAutocapitalization(.words)
                    TextField("Região", text: $region)
                        .textInputAutocapitalization(.words)
                }

                Section("Adega") {
                    Stepper(value: $bottles, in: 0...999) {
                        HStack {
                            Text("Garrafas")
                            Spacer()
                            Text("\(bottles)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TextField("Classificação (ex.: Gran Reserva)", text: $classification)
                    TextField("Teor alcoólico", text: $alcohol)
                    TextField("Amadurecimento", text: $aging, axis: .vertical)
                    TextField("Temperatura de serviço", text: $servingTemp)
                    TextField("Potencial de guarda", text: $cellaring)
                    TextField("Pontuações", text: $ratings, axis: .vertical)
                    TextField("Preço (lojas e faixa)", text: $priceSummary, axis: .vertical)
                    TextField("Notas de degustação", text: $tastingNotes, axis: .vertical)
                        .lineLimit(2...8)
                    TextField("Harmonização", text: $pairing, axis: .vertical)
                    TextField("Sobre o produtor e o vinho", text: $about, axis: .vertical)
                        .lineLimit(2...10)
                } header: {
                    Text("Ficha")
                } footer: {
                    if !sources.isEmpty {
                        Text("Pesquisado em \(sources.count) fonte\(sources.count == 1 ? "" : "s") na web.")
                    }
                }

                Section("Observações") {
                    TextField("Onde comprou, quando abrir, harmonização…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(wine == nil ? "Novo vinho" : "Editar vinho")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photo = image.jpegForStorage()
                        lerRotuloAutomatico()
                    }
                    photoItem = nil
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    photo = image.jpegForStorage()
                    lerRotuloAutomatico()
                }
                .ignoresSafeArea()
            }
        }
    }

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                if let photo, let image = UIImage(data: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(wineType.color.opacity(0.18))
                        .frame(width: 150, height: 200)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "camera")
                                    .font(.title)
                                Text("Foto do rótulo")
                                    .font(.caption)
                            }
                            .foregroundStyle(wineType.color)
                        }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)

            HStack(spacing: 20) {
                Spacer()
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Câmera", systemImage: "camera") { showingCamera = true }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Galeria", systemImage: "photo.on.rectangle")
                }
                if photo != nil {
                    Button("Remover", systemImage: "trash", role: .destructive) { photo = nil }
                }
                Spacer()
            }
            .buttonStyle(.borderless)
            .font(.subheadline)

            if photo != nil {
                Button {
                    Task { await lerRotulo() }
                } label: {
                    HStack {
                        Spacer()
                        if lendoRotulo {
                            ProgressView()
                            Text("Lendo e pesquisando o vinho…")
                        } else {
                            Label(rotuloPreenchido ? "Ler de novo com IA" : "Preencher com IA", systemImage: "sparkles")
                        }
                        Spacer()
                    }
                }
                .disabled(lendoRotulo)

                if lendoRotulo {
                    Text("A IA está buscando produtor, notas, harmonização, preços e avaliações de especialistas na internet. Leva de 30 segundos a 1 minuto.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let erroRotulo {
                    Text(erroRotulo)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    /// Ao escolher a foto de um vinho novo, já tenta ler o rótulo (se o token estiver configurado).
    private func lerRotuloAutomatico() {
        guard wine == nil, ChaveAnthropic.configurada else { return }
        Task { await lerRotulo() }
    }

    private func lerRotulo() async {
        guard let photo, !lendoRotulo else { return }
        lendoRotulo = true
        erroRotulo = nil
        defer { lendoRotulo = false }
        do {
            let rotulo = try await LeitorRotulo.ler(jpeg: photo)
            aplicar(rotulo)
            rotuloPreenchido = true
        } catch {
            erroRotulo = error.localizedDescription
        }
    }

    /// Preenche só os campos vazios — não apaga o que você já digitou.
    private func aplicar(_ r: RotuloLido) {
        func preencher(_ campo: inout String, _ valor: String) {
            if campo.trimmingCharacters(in: .whitespaces).isEmpty { campo = valor }
        }
        preencher(&name, r.nome)
        preencher(&producer, r.produtor)
        if vintageText.isEmpty, let safra = r.safra { vintageText = String(safra) }
        preencher(&grape, r.uva)
        preencher(&country, r.pais)
        preencher(&region, r.regiao)
        preencher(&classification, r.classificacao)
        preencher(&alcohol, r.teorAlcoolico)
        preencher(&aging, r.amadurecimento)
        preencher(&tastingNotes, r.notasDegustacao)
        preencher(&pairing, r.harmonizacao)
        preencher(&servingTemp, r.temperaturaServico)
        preencher(&cellaring, r.potencialGuarda)
        preencher(&ratings, r.pontuacoes)
        preencher(&about, r.sobre)
        if !r.fontes.isEmpty { sources = r.fontes }
        if let tipo = WineType(rawValue: r.tipo) { wineType = tipo }
        // preço e avaliações mudam com o tempo: sempre ficam com a pesquisa mais recente
        priceBRL = r.precoMedioBRL
        if let resumo = r.precoResumo { priceSummary = resumo }
        if !r.reviews.isEmpty { reviews = r.reviews }
        researchedAt = .now
    }

    private func save() {
        let target: Wine
        if let wine {
            target = wine
        } else {
            target = Wine(name: "")
            context.insert(target)
        }
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        target.name = trim(name)
        target.producer = trim(producer)
        target.vintage = Int(trim(vintageText))
        target.wineType = wineType
        target.grape = trim(grape)
        target.country = trim(country)
        target.region = trim(region)
        target.bottles = bottles
        target.notes = trim(notes)
        target.photo = photo
        target.classification = trim(classification)
        target.alcohol = trim(alcohol)
        target.aging = trim(aging)
        target.tastingNotes = trim(tastingNotes)
        target.pairing = trim(pairing)
        target.servingTemp = trim(servingTemp)
        target.cellaring = trim(cellaring)
        target.ratings = trim(ratings)
        target.about = trim(about)
        target.sources = sources
        target.priceBRL = priceBRL
        target.priceSummary = trim(priceSummary)
        target.reviews = reviews
        target.researchedAt = researchedAt
        dismiss()
    }
}
