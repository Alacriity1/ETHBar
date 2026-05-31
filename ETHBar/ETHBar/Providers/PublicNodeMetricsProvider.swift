import Foundation

final class PublicNodeMetricsProvider: ChainMetricsProvider {
    let network: EthereumNetwork
    private var cachedCurrentBlockNumber: Int?

    var sourceName: String {
        "PublicNode WebSocket"
    }

    init(network: EthereumNetwork = .mainnet) {
        self.network = network
    }

    func feeHistory(blockCount: Int, newestBlock: Int) async throws -> [ChainMetricPoint] {
        let client = EthereumHTTPRPCClient(endpointURL: network.httpURL)
        let feeHistory = try await client.feeHistory(blockCount: blockCount, newestBlock: newestBlock)

        return feeHistory.chainMetricPoints()
    }

    func currentBlockNumber() async throws -> Int {
        if let cachedCurrentBlockNumber {
            return cachedCurrentBlockNumber
        }

        let client = EthereumHTTPRPCClient(endpointURL: network.httpURL)
        let fetchedBlockNumber = try await client.blockNumber()
        cachedCurrentBlockNumber = fetchedBlockNumber

        return fetchedBlockNumber
    }

    func subscribeToMetrics() -> AsyncThrowingStream<EthereumMetrics, Error> {
        let client = SubscriptionClient(endpointURL: network.webSocketURL)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await header in client.blockHeaders() {
                        self.cachedCurrentBlockNumber = header.number

                        let metrics = EthereumMetrics(
                            networkName: network.name,
                            baseFeeGwei: header.baseFeePerGasGwei,
                            blockNumber: header.number,
                            gasUsedPercent: header.gasUsedPercent,
                            updatedAt: header.timestamp,
                            sourceName: sourceName
                        )

//                        ETHBarLog.debug("Metrics from block header: \(metrics)", category: .provider)
                        continuation.yield(metrics)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
