import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: EthereumMetricsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            BaseFeeHistoryView(points: store.history.points)

            Divider()

            GasUsageHistoryView(points: store.history.points)

            Divider()

            CurrentBlockSection(
                blockNumber: blockNumberText,
                baseFee: compactBaseFeeText,
                gasUsed: gasUsedText
            )

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Quit") {
                Task { @MainActor in
                    await store.stopAndSaveCurrentHistory()
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
            return store.isLoading ? "Awaiting next block" : "--"
        }

        return "\(store.metrics.baseFeeGwei.formatted(.number.precision(.fractionLength(0...3)))) gwei"
    }

    private var compactBaseFeeText: String {
        guard store.metrics.baseFeeGwei > 0 else {
            return "--"
        }

        return baseFeeText
    }

    private var blockNumberText: String {
        guard store.metrics.blockNumber > 0 else {
            return store.isLoading ? "Awaiting" : "--"
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

private struct CurrentBlockSection: View {
    let blockNumber: String
    let baseFee: String
    let gasUsed: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label {
                    Text("Current block")
                        .font(.headline)
                        .fontWeight(.bold)
                } icon: {
                    Image(systemName: "cube")
                        .font(.subheadline)
                }
                .foregroundStyle(.primary)

                Spacer()

                Text(blockNumber)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 10) {
                CurrentBlockMetric(
                    title: "Base fee",
                    value: baseFee
                )

                CurrentBlockMetric(
                    title: "Gas used",
                    value: gasUsed
                )
            }
            .frame(height: 68)
        }
    }
}

private struct CurrentBlockMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        }
    }
}

//For Xcode’s SwiftUI preview canvas.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: EthereumMetricsStore(autostart: false))
    }
}
