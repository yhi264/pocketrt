import SwiftUI

struct ResultCard<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content
    let isDisabled: Bool

    init(title: LocalizedStringKey, isDisabled: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isDisabled = isDisabled
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDisabled ? Color(.systemGray5) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        )
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}
