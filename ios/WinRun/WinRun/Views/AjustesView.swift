import SwiftUI

struct AjustesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var endereco = Servidor.endereco
    @State private var token = Servidor.token ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Endereço", text: $endereco)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Servidor (leitura de rótulo com IA)")
                } footer: {
                    Text("É o mesmo TREINO_API_TOKEN do site marcioscar. O token fica guardado no Keychain do iPhone.")
                }

                Section {
                    Button("Restaurar endereço padrão") {
                        endereco = Servidor.enderecoPadrao
                    }
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
                        Servidor.endereco = endereco
                        Servidor.token = token
                        dismiss()
                    }
                }
            }
        }
    }
}
