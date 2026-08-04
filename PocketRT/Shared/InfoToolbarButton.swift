import SwiftUI

/// 各タブのツールバーに置く ⓘ ボタン。タップで情報画面をシート表示する。
struct InfoToolbarButton: ViewModifier {
    @State private var showInfo = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("情報")
                }
            }
            .sheet(isPresented: $showInfo) { InfoView() }
    }
}

extension View {
    func infoToolbarButton() -> some View { modifier(InfoToolbarButton()) }
}
