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
    private var liveUpdatesTask: Task<Void, Never>?

    init(provider: (any EthereumMetricsProvider)? = nil, autostart: Bool = true) {
        self.provider = provider ?? PublicNodeMetricsProvider()

        if autostart {
            startLiveUpdates()
        }
    }

    var menuBarTitle: String {
        guard metrics.baseFeeGwei > 0 else {
            return "ETH --"
        }

        return "ETH \(Self.gweiFormatter.string(from: metrics.baseFeeGwei as NSNumber) ?? "--") gwei"
    }

    func startLiveUpdates() {
        guard liveUpdatesTask == nil else {
            return
        }

        ETHBarLog.debug("Live updates started", category: .store)
        isLoading = true
        errorMessage = nil

        liveUpdatesTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                for try await nextMetrics in provider.subscribeToMetrics() {
                    metrics = nextMetrics
                    isLoading = false
                    ETHBarLog.debug("Live metrics received: \(nextMetrics)", category: .store)
                }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                ETHBarLog.debug("Live updates failed: \(error.localizedDescription)", category: .store)
            }
        }
    }

    func stopLiveUpdates() {
        ETHBarLog.debug("Live updates stopped", category: .store)
        liveUpdatesTask?.cancel()
        liveUpdatesTask = nil
    }

    private static let gweiFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        return formatter
    }()

}
