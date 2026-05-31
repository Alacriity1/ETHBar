import Foundation

struct EthereumBlockHeader: Equatable {
    let number: Int
    let baseFeePerGasGwei: Double
    let gasUsed: Int
    let gasLimit: Int
    let timestamp: Date
}

extension EthereumBlockHeader {
    var gasUsedPercent: Double {
        guard gasLimit > 0 else {
            return 0
        }

        return Double(gasUsed) / Double(gasLimit)
    }
}
