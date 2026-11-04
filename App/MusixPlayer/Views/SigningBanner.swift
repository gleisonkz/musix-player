import MusixCore
import SwiftUI

/// Shows when the sideloaded (free Apple ID, 7-day) build stops opening.
struct SigningBanner: View {
    private let expiration = SigningExpiry.expirationDate()

    var body: some View {
        switch SigningExpiry.status(expiration: expiration) {
        case .unknown:
            EmptyView()
        case let .ok(days):
            label("Assinatura válida por \(days) dias (\(dateText))", color: .secondary, icon: "checkmark.seal")
        case let .warning(days):
            label(days == 0 ? "Assinatura vence HOJE (\(dateText)). Reassine antes do show!"
                            : "Assinatura vence em \(days) dia (\(dateText)). Reassine antes do show!",
                  color: .orange, icon: "exclamationmark.triangle.fill")
        case .expired:
            label("Assinatura vencida", color: .red, icon: "xmark.seal.fill")
        }
    }

    private var dateText: String {
        expiration?.formatted(date: .abbreviated, time: .shortened) ?? ""
    }

    private func label(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.medium))
            .foregroundStyle(color)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.bar)
    }
}
