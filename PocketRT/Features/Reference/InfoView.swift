import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("計算の根拠") {
                    NavigationLink("計算式と α/β の解説") { ReferenceView() }
                    NavigationLink("プリセットの出典") { CitationListView() }
                }
                Section("ご利用にあたって") {
                    NavigationLink("免責事項") {
                        ScrollView { DisclaimerBody().padding() }
                            .navigationTitle("免責事項")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    NavigationLink("プライバシーポリシー") { PrivacyPolicyView() }
                }
                Section("このアプリについて") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(versionText)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
