import SwiftUI
import UIKit

// MARK: - Cores por tipo

extension WineType {
    var color: Color {
        switch self {
        case .tinto: Color(red: 0.62, green: 0.11, blue: 0.24)
        case .branco: Color(red: 0.90, green: 0.82, blue: 0.48)
        case .rose: Color(red: 0.95, green: 0.55, blue: 0.62)
        case .espumante: Color(red: 0.85, green: 0.75, blue: 0.40)
        case .sobremesa: Color(red: 0.86, green: 0.55, blue: 0.18)
        case .fortificado: Color(red: 0.50, green: 0.24, blue: 0.14)
        }
    }
}

// MARK: - Miniatura do vinho

struct WineThumbnail: View {
    let wine: Wine
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let data = wine.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    wine.wineType.color.opacity(0.22)
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(wine.wineType.color)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Etiqueta do tipo

struct WineTypeBadge: View {
    let type: WineType

    var body: some View {
        Text(type.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(type.color.opacity(0.22), in: Capsule())
            .foregroundStyle(type.color)
    }
}

// MARK: - Estrelas

/// Estrelas editáveis (toque para dar nota; toque de novo na mesma para tirar).
struct StarRatingView: View {
    @Binding var rating: Int
    var maximum = 5
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maximum, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index <= rating ? Color.yellow : Color.secondary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        rating = (rating == index) ? index - 1 : index
                    }
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
        .accessibilityElement()
        .accessibilityLabel("Nota")
        .accessibilityValue("\(rating) de \(maximum)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(maximum, rating + 1)
            case .decrement: rating = max(0, rating - 1)
            @unknown default: break
            }
        }
    }
}

/// Estrelas somente leitura (aceita meia estrela, útil para médias).
struct StarsLabel: View {
    let rating: Double
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                let value = rating - Double(index - 1)
                Image(systemName: value >= 1 ? "star.fill" : value >= 0.5 ? "star.leadinghalf.filled" : "star")
            }
        }
        .font(.system(size: size))
        .foregroundStyle(.yellow)
        .accessibilityElement()
        .accessibilityLabel(String(format: "Nota %.1f de 5", rating))
    }
}

// MARK: - Imagem

extension UIImage {
    /// Reduz a foto e converte para JPEG antes de salvar (rótulos não precisam de 12 MP).
    func jpegForStorage(maxDimension: CGFloat = 1400) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Câmera

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Formatação

nonisolated enum Fmt {
    static func price(_ value: Double) -> String {
        value.formatted(.currency(code: "BRL"))
    }

    /// Aceita "89,90" ou "89.90".
    static func parsePrice(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    static func priceText(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }
}
