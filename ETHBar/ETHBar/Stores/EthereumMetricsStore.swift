import Combine
import Foundation

// app state layer
//Purpose: keep async loading, errors, formatting, and observable UI state out of the provider and out of the view. The view just observes the store.

@MainActor
final class EthereumMetricsStore: ObservableObject {
    @Published private(set) var metrics: EthereumMetrics = .placeholder
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let provider: any EthereumMetricsProvider

    init(provider: (any EthereumMetricsProvider)? = nil) {
        self.provider = provider ?? PublicRPCMetricsProvider()
    }

    var menuBarTitle: String {
        guard metrics.gasPriceGwei > 0 else {
            return "ETH --"
        }

        return "ETH \(Self.gweiFormatter.string(from: metrics.gasPriceGwei as NSNumber) ?? "--") gwei"
    }

    func refresh() async {
        debugLog("Refresh started")
        isLoading = true
        errorMessage = nil

        do {
            metrics = try await provider.fetchMetrics()
            debugLog("Refresh succeeded: \(metrics)")
        } catch {
            errorMessage = error.localizedDescription
            debugLog("Refresh failed: \(error.localizedDescription)")
        }

        isLoading = false
        debugLog("Refresh finished")
    }

    private static let gweiFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        return formatter
    }()

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[ETHBar][Store] \(message)")
        #endif
    }
}
