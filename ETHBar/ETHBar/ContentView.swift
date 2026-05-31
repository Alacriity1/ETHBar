import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: EthereumMetricsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            MetricRow(title: "Gas price", value: gasPriceText, systemImage: "fuelpump")
            MetricRow(title: "Block", value: blockNumberText, systemImage: "cube")
            MetricRow(title: "Transactions/sec", value: "--", systemImage: "waveform.path.ecg")

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            HStack {
                Button("Refresh") {
                    Task {
                        await store.refresh()
                    }
                }
                .disabled(store.isLoading)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(18)
        .frame(width: 320)
        .task {
            await store.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ETHBar")
                    .font(.headline)
                Text(store.metrics.networkName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(lastUpdatedText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gasPriceText: String {
        guard store.metrics.gasPriceGwei > 0 else {
            return store.isLoading ? "Loading" : "--"
        }

        return "\(store.metrics.gasPriceGwei.formatted(.number.precision(.fractionLength(0...1)))) gwei"
    }

    private var blockNumberText: String {
        guard store.metrics.blockNumber > 0 else {
            return "--"
        }

        return store.metrics.blockNumber.formatted()
    }

    private var lastUpdatedText: String {
        if store.isLoading {
            return "Updating"
        }

        guard store.metrics.sourceName != "Not loaded" else {
            return "Not loaded"
        }

        return store.metrics.updatedAt.formatted(date: .omitted, time: .shortened)
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
        ContentView(store: EthereumMetricsStore())
    }
}
