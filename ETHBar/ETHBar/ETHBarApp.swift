import SwiftUI

@main //app root
struct ETHBarApp: App {
    @StateObject private var metricsStore = EthereumMetricsStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: metricsStore)
        } label: {
            Label {
                Text(metricsStore.menuBarTitle)
            } icon: {
                Image("EthereumMenuBarLogo")
                    .renderingMode(.template)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
