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

    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false

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
                    }
                    photoItem = nil
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    photo = image.jpegForStorage()
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
        }
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
        dismiss()
    }
}
