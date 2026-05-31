import Foundation

//This is the first concrete provider

struct PublicNodeMetricsProvider: EthereumMetricsProvider {
    let network: EthereumNetwork

    var sourceName: String {
        "PublicNode WebSocket"
    }

    init(network: EthereumNetwork = .mainnet) {
        self.network = network
    }

    func subscribeToMetrics() -> AsyncThrowingStream<EthereumMetrics, Error> {
        let client = EthereumBlockSubscriptionClient(endpointURL: network.webSocketURL)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await header in client.blockHeaders() {
                        let metrics = EthereumMetrics(
                            networkName: network.name,
                            baseFeeGwei: header.baseFeePerGasGwei,
                            blockNumber: header.number,
                            gasUsedPercent: header.gasUsedPercent,
                            updatedAt: header.timestamp,
                            sourceName: sourceName
                        )

                        ETHBarLog.debug("Metrics from block header: \(metrics)", category: .provider)
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
