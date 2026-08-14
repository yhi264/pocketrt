import SwiftUI

@main
struct PocketRTApp: App {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    // 保存先の解決に失敗した場合、一時ディレクトリへはフォールバックしない。
    // 一時ディレクトリは OS が任意に消しうるため、利用者には「登録なし」に
    // 見える形で登録が消えかねない。失敗は PresetStoreModel 側で
    // loadFailure として扱う。
    @State private var presetStore = PresetStoreModel(store: try? InstitutionalPresetStore.default())

    var body: some Scene {
        WindowGroup {
            TabView {
                SimpleCalcView()
                    .tabItem { Label("計算", systemImage: "function") }

                MultiCourseView()
                    .tabItem { Label("合算", systemImage: "sum") }

                FractionationConversionView()
                    .tabItem { Label("換算", systemImage: "arrow.left.arrow.right") }

                ScheduleView()
                    .tabItem { Label("予定", systemImage: "calendar") }

                PlanQualityView()
                    .tabItem { Label("品質", systemImage: "checkmark.seal") }
            }
            .environment(presetStore)
            .fullScreenCover(isPresented: Binding(
                get: { !hasAcceptedDisclaimer },
                set: { hasAcceptedDisclaimer = !$0 }
            )) {
                DisclaimerView(hasAccepted: Binding(
                    get: { hasAcceptedDisclaimer },
                    set: { hasAcceptedDisclaimer = $0 }
                ))
            }
        }
    }
}
