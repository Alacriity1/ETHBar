import Combine
import Foundation

//app state layer
//Purpose: keep async loading, errors, formatting, and observable UI state out of the provider and out of the view. The view just observes the store.

@MainActor
final class EthereumMetricsStore: ObservableObject {
    @Published private(set) var metrics: EthereumMetrics = .placeholder
    @Published private(set) var history = ChainMetricHistory(
        chainID: EthereumNetwork.mainnet.chainID,
        networkName: EthereumNetwork.mainnet.name,
        points: []
    )
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let provider: any ChainMetricsProvider
    private let historyCache: ChainMetricHistoryCache
    private var liveUpdatesTask: Task<Void, Never>?

    init(
        provider: (any ChainMetricsProvider)? = nil,
        historyCache: ChainMetricHistoryCache = ChainMetricHistoryCache(
            chainID: EthereumNetwork.mainnet.chainID,
            networkName: EthereumNetwork.mainnet.name
        ),
        autostart: Bool = true
    ) {
        self.provider = provider ?? PublicNodeMetricsProvider()
        self.historyCache = historyCache

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

            await loadCachedHistory()
            await syncHistory()

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

    private func loadCachedHistory() async {
        do {
            let cachedHistory = try await historyCache.loadHistory()
            guard !Task.isCancelled else {
                return
            }

            history = cachedHistory
            ETHBarLog.debug(
                "Loaded \(cachedHistory.points.count) cached history points for chain \(cachedHistory.chainID)",
                category: .store
            )
        } catch {
            ETHBarLog.debug("History cache load failed: \(error.localizedDescription)", category: .store)
        }
    }

    private static let gweiFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        return formatter
    }()
    
//    Missing older part of target window -> Fetch whole 7-day target window.
//    Otherwise, only missing newest blocks -> Fetch just newest missing blocks.
//    Already covers target window -> Fetch nothing.
    private func syncHistory() async {
        do {
            guard !Task.isCancelled else {
                return
            }

            let currentHead = try await provider.currentBlockNumber()
            let targetBlockCount = ChainMetricHistoryCache.defaultRetainedBlockCount
            let targetStartBlock = max(0, currentHead - targetBlockCount + 1)

            let fetchStartBlock: Int //optimize later, I think blocks "near' the first and last block should be fine
            if let firstBlock = history.firstBlockNumber,
               let lastBlock = history.lastBlockNumber {
                let needsOlderHistory = firstBlock > targetStartBlock
                let needsNewerHistory = lastBlock < currentHead

                guard needsOlderHistory || needsNewerHistory else {
                    ETHBarLog.debug("History already covers target block window", category: .store)
                    return
                }

                fetchStartBlock = needsOlderHistory ? targetStartBlock : lastBlock + 1
            } else {
                fetchStartBlock = targetStartBlock
            }

            let blockCount = currentHead - fetchStartBlock + 1
            guard blockCount > 0 else { return }

            let maxFeeHistoryBlockCount = 1024

            var allPoints: [ChainMetricPoint] = []
            var chunkStart = fetchStartBlock

            while chunkStart <= currentHead {
                let chunkEnd = min(chunkStart + maxFeeHistoryBlockCount - 1, currentHead)
                let chunkBlockCount = chunkEnd - chunkStart + 1

                let chunkPoints = try await provider.feeHistory(
                    blockCount: chunkBlockCount,
                    newestBlock: chunkEnd
                )

                allPoints.append(contentsOf: chunkPoints)
                chunkStart = chunkEnd + 1
            }

            let mergedHistory = await historyCache.mergedHistory(
                existingHistory: history,
                newPoints: allPoints
            )
            guard !Task.isCancelled else {
                return
            }

            history = mergedHistory
            try await historyCache.saveHistory(mergedHistory)

            ETHBarLog.debug(
                "Saved \(mergedHistory.points.count) history points",
                category: .store
            )
        } catch {
            ETHBarLog.debug(
                "Fee history fetch failed: \(error.localizedDescription)",
                category: .store
            )
        }
    }

}
