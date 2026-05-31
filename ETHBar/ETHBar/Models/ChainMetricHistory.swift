import Foundation

struct ChainMetricHistory: Codable, Equatable, Identifiable {
    let chainID: Int
    let networkName: String
    var points: [ChainMetricPoint]

    var id: Int {
        chainID
    }

    var firstBlockNumber: Int? {
        points.first?.blockNumber
    }

    var lastBlockNumber: Int? {
        points.last?.blockNumber
    }
}

struct ChainMetricPoint: Codable, Equatable, Identifiable {
    let blockNumber: Int
    let timestamp: Date?
    let baseFeeGwei: Double
    let gasUsedRatio: Double

    var id: Int {
        blockNumber
    }
}

