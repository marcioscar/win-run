import SwiftUI

struct AjustesView: View {
    @Environment(\.dismiss) private var dismiss

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
