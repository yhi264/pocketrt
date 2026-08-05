import SwiftUI

struct ReferenceView: View {
    var body: some View {
        List {
            ForEach(ReferenceContent.sections) { section in
                // Section(_ titleResource: LocalizedStringResource) only exists in the
                // Xcode 26 SDK. CI builds with Xcode 16.4, where the literal-taking
                // overloads are LocalizedStringKey and StringProtocol only, so passing
                // the resource directly fails to compile there. The header: form works
                // on both and localizes identically.
                Section {
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
                } header: {
                    Text(section.title)
                }
            }
        }
        .navigationTitle("計算式と α/β")
        .navigationBarTitleDisplayMode(.inline)
    }
}
