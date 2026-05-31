import Foundation

//defines the normalized data shape the app wants

struct EthereumMetrics: Equatable {
    let networkName: String
    let baseFeeGwei: Double
    let blockNumber: Int
    let gasUsedPercent: Double
    let updatedAt: Date
    let sourceName: String
}

extension EthereumMetrics {
    static let placeholder = EthereumMetrics(
        networkName: "N/A",
        baseFeeGwei: 0,
        blockNumber: 0,
        gasUsedPercent: 0,
        updatedAt: Date(),
        sourceName: "Not loaded"
    )
}
