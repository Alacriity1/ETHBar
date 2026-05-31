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
    private var pollingTask: Task<Void, Never>?
    private let refreshInterval: Duration

    init(provider: (any EthereumMetricsProvider)? = nil, refreshInterval: Duration = .seconds(12)) {
        self.provider = provider ?? PublicRPCMetricsProvider()
        self.refreshInterval = refreshInterval
        startPolling()
    }

    var menuBarTitle: String {
        guard metrics.gasPriceGwei > 0 else {
            return "ETH --"
        }

        return "ETH \(Self.gweiFormatter.string(from: metrics.gasPriceGwei as NSNumber) ?? "--") gwei"
    }

    func refresh() async {
        guard !isLoading else {
            debugLog("Refresh skipped because another refresh is already in progress")
            return
        }

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

    func startPolling() {
        guard pollingTask == nil else {
            return
        }

        debugLog("Polling started")
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()

                do {
                    try await Task.sleep(for: self?.refreshInterval ?? .seconds(12))
                } catch {
                    break
                }
            }
        }
    }

    func stopPolling() {
        debugLog("Polling stopped")
        pollingTask?.cancel()
        pollingTask = nil
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
