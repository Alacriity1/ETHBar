import Foundation

//This is the first concrete provider

struct PublicRPCMetricsProvider: EthereumMetricsProvider {
    let network: EthereumNetwork

    var sourceName: String {
        "PublicNode RPC"
    }

    init(network: EthereumNetwork = .mainnet) {
        self.network = network
    }

    func fetchMetrics() async throws -> EthereumMetrics {
        debugLog("Fetching metrics for \(network.name) from \(network.rpcURL.absoluteString)")

        let client = EthereumRPCClient(endpointURL: network.rpcURL)

        async let gasPriceWei = client.gasPriceWei()
        async let blockNumber = client.blockNumber()

        let metrics = EthereumMetrics(
            networkName: network.name,
            gasPriceGwei: Double(try await gasPriceWei) / 1_000_000_000,
            blockNumber: try await blockNumber,
            updatedAt: Date(),
            sourceName: sourceName
        )

        debugLog("Fetched metrics: gas=\(metrics.gasPriceGwei) gwei block=\(metrics.blockNumber)")
        return metrics
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[ETHBar][Provider] \(message)")
        #endif
    }
}
