import SwiftUI

@main
struct ETHBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Label("ETH 18 gwei", systemImage: "bolt.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
