import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AjustesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var wines: [Wine]

    // backup
    @State private var documento: BackupDocumento?
    @State private var mostrandoExportar = false
    @State private var mostrandoImportar = false
    @State private var preparando = false
    @State private var backupLido: BackupArquivo?
    @State private var mensagemBackup: (ok: Bool, texto: String)?

    @State private var chave = ChaveAnthropic.valor ?? ""
    @State private var testando = false
    @State private var resultadoTeste: (ok: Bool, mensagem: String)?

    private var chaveLimpa: String { chave.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $chave)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: chave) { resultadoTeste = nil }

                    Button {
                        Task { await testar() }
                    } label: {
                        HStack {
                            if testando { ProgressView() }
                            Text(testando ? "Testando…" : "Testar chave")
                        }
                    }
                    .disabled(chaveLimpa.isEmpty || testando)

                    if let resultadoTeste {
                        Label(resultadoTeste.mensagem,
                              systemImage: resultadoTeste.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(resultadoTeste.ok ? .green : .red)
                            .font(.footnote)
                    }
                } header: {
                    Text("Chave da API da Anthropic")
                } footer: {
                    Text("A IA lê o rótulo e pesquisa o vinho usando a sua chave; cada pesquisa completa custa alguns centavos de dólar na sua conta. A chave fica só no Keychain deste iPhone.")
                }

                Section {
                    Button {
                        Task { await prepararExportacao() }
                    } label: {
                        HStack {
                            if preparando { ProgressView() }
                            Label("Exportar backup", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(wines.isEmpty || preparando)

                    Button {
                        mostrandoImportar = true
                    } label: {
                        Label("Importar backup", systemImage: "square.and.arrow.down")
                    }

                    if let mensagemBackup {
                        Label(mensagemBackup.texto,
                              systemImage: mensagemBackup.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(mensagemBackup.ok ? .green : .red)
                            .font(.footnote)
                    }
                } header: {
                    Text("Backup da adega")
                } footer: {
                    Text("Os vinhos ficam só neste iPhone: se apagar o app, eles somem. Exporte de vez em quando e guarde o arquivo no iCloud Drive (app Arquivos). O backup inclui fotos, fichas e degustações — não inclui a chave da API.")
                }

                Section("Como conseguir uma chave") {
                    Link(destination: URL(string: "https://platform.claude.com/settings/keys")!) {
                        Label("Criar chave em platform.claude.com", systemImage: "key")
                    }
                    Link(destination: URL(string: "https://platform.claude.com/settings/billing")!) {
                        Label("Comprar créditos (Billing)", systemImage: "creditcard")
                    }
                    Text("A chave da API é diferente da assinatura do Claude: é preciso ter créditos na conta da plataforma.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        ChaveAnthropic.valor = chaveLimpa
                        dismiss()
                    }
                }
            }
            .fileExporter(isPresented: $mostrandoExportar, document: documento, contentType: .json,
                          defaultFilename: "WinRun-backup-\(Date.now.formatted(.iso8601.year().month().day()))") { resultado in
                switch resultado {
                case .success:
                    mensagemBackup = (true, "Backup salvo com \(wines.count) vinho\(wines.count == 1 ? "" : "s").")
                case .failure(let erro):
                    mensagemBackup = (false, "Não foi possível salvar: \(erro.localizedDescription)")
                }
                documento = nil
            }
            .fileImporter(isPresented: $mostrandoImportar, allowedContentTypes: [.json]) { resultado in
                lerArquivo(resultado)
            }
            .confirmationDialog(tituloImportacao, isPresented: Binding(
                get: { backupLido != nil },
                set: { if !$0 { backupLido = nil } }
            ), titleVisibility: .visible) {
                Button("Juntar com a adega atual") { importar(substituir: false) }
                Button("Substituir tudo", role: .destructive) { importar(substituir: true) }
                Button("Cancelar", role: .cancel) { backupLido = nil }
            } message: {
                Text("Juntar: adiciona só os vinhos que ainda não estão na adega (mesmo nome, produtor e safra).\nSubstituir: apaga a adega atual (\(wines.count) vinhos) e coloca a do backup.")
            }
        }
    }

    // MARK: - Backup

    private var tituloImportacao: String {
        guard let b = backupLido else { return "Importar backup" }
        return "Importar \(b.vinhos.count) vinho\(b.vinhos.count == 1 ? "" : "s") de \(b.exportadoEm.formatted(date: .abbreviated, time: .omitted))?"
    }

    private func prepararExportacao() async {
        preparando = true
        defer { preparando = false }
        let backup = Backup.montar(wines)
        do {
            // gerar o JSON (com fotos) fora da thread principal
            let dados = try await Task.detached { try Backup.codificar(backup) }.value
            documento = BackupDocumento(dados: dados)
            mostrandoExportar = true
        } catch {
            mensagemBackup = (false, "Erro ao gerar o backup: \(error.localizedDescription)")
        }
    }

    private func lerArquivo(_ resultado: Result<URL, Error>) {
        do {
            let url = try resultado.get()
            let acessou = url.startAccessingSecurityScopedResource()
            defer { if acessou { url.stopAccessingSecurityScopedResource() } }
            backupLido = try Backup.decodificar(Data(contentsOf: url))
        } catch {
            mensagemBackup = (false, "Não foi possível ler o arquivo: \(error.localizedDescription)")
        }
    }

    private func importar(substituir: Bool) {
        guard let backup = backupLido else { return }
        backupLido = nil
        do {
            let r = try Backup.importar(backup, em: context, existentes: wines, substituir: substituir)
            var texto = "\(r.novos) vinho\(r.novos == 1 ? "" : "s") importado\(r.novos == 1 ? "" : "s")"
            if r.pulados > 0 { texto += "; \(r.pulados) já estava\(r.pulados == 1 ? "" : "m") na adega" }
            mensagemBackup = (true, texto + ".")
        } catch {
            mensagemBackup = (false, "Erro ao importar: \(error.localizedDescription)")
        }
    }

    private func testar() async {
        testando = true
        defer { testando = false }
        do {
            try await AnthropicAPI.testarChave(chaveLimpa)
            resultadoTeste = (true, "Chave válida. Lembre de ter créditos na conta.")
        } catch {
            resultadoTeste = (false, error.localizedDescription)
        }
    }
}
