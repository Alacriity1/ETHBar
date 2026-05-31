import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: EthereumMetricsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            MetricRow(title: "Base fee", value: baseFeeText, systemImage: "fuelpump")
            MetricRow(title: "Block", value: blockNumberText, systemImage: "cube")
            MetricRow(title: "Gas used", value: gasUsedText, systemImage: "gauge.with.dots.needle.bottom.50percent")

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
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

    private var baseFeeText: String {
        guard store.metrics.baseFeeGwei > 0 else {
            return store.isLoading ? "Loading" : "--"
        }

        return "\(store.metrics.baseFeeGwei.formatted(.number.precision(.fractionLength(0...3)))) gwei"
    }

    private var blockNumberText: String {
        guard store.metrics.blockNumber > 0 else {
            return "--"
        }

        return store.metrics.blockNumber.formatted()
    }

    private var gasUsedText: String {
        guard store.metrics.gasUsedPercent > 0 else {
            return "--"
        }

        return store.metrics.gasUsedPercent.formatted(.percent.precision(.fractionLength(0...1)))
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

//For Xcode’s SwiftUI preview canvas.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: EthereumMetricsStore(autostart: false))
    }
}
