import Foundation

//This is the first concrete provider

struct PublicRPCMetricsProvider: EthereumMetricsProvider {
    let network: EthereumNetwork

    var sourceName: String {
        "PublicNode RPC"
    }

    init(network: EthereumNetwork = .mainnet) {
        print("--- RPCProvider init")
        self.network = network
//        print("network: \(network)")
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

                        debugLog("Metrics from block header: \(metrics)")
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

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[ETHBar][Provider] \(message)")
        #endif
    }
}
