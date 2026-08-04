import SwiftUI

struct ReferenceView: View {
    var body: some View {
        List {
            ForEach(ReferenceContent.sections) { section in
                Section(section.title) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let formula = section.formula {
                            Text(formula)
                                .font(.callout.monospaced())
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                        Text(section.body)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("計算式と α/β")
        .navigationBarTitleDisplayMode(.inline)
    }
}
