import Foundation

//defines the normalized data shape the app wants

struct EthereumMetrics: Equatable {
    let networkName: String
    let gasPriceGwei: Double
    let blockNumber: Int
    let updatedAt: Date
    let sourceName: String
}

extension EthereumMetrics {
    static let placeholder = EthereumMetrics(
        networkName: "Ethereum Mainnet",
        gasPriceGwei: 0,
        blockNumber: 0,
        updatedAt: Date(),
        sourceName: "Not loaded"
    )
}
