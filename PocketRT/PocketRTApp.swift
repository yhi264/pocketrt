import SwiftUI

@main
struct PocketRTApp: App {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

    var body: some Scene {
        WindowGroup {
            TabView {
                SimpleCalcView()
                    .tabItem { Label("計算", systemImage: "function") }

                MultiCourseView()
                    .tabItem { Label("合算", systemImage: "sum") }

                OARConversionView()
                    .tabItem { Label("換算", systemImage: "arrow.left.arrow.right") }

                ScheduleView()
                    .tabItem { Label("予定", systemImage: "calendar") }
            }
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
