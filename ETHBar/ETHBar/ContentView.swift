import AppKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            MetricRow(title: "Base fee", value: "18 gwei", systemImage: "fuelpump")
            MetricRow(title: "Priority fee", value: "2 gwei", systemImage: "arrow.up.forward.circle")
            MetricRow(title: "Block", value: "Pending", systemImage: "cube")
            MetricRow(title: "Transactions/sec", value: "--", systemImage: "waveform.path.ecg")

            Divider()

            HStack {
                Button("Refresh") {
                    // Live Ethereum metric refresh will land with the data provider layer.
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(18)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ETHBar")
                    .font(.headline)
                Text("Ethereum network")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Updated just now")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.tint)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.body)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
