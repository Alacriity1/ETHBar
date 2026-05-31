import Foundation

protocol ChainMetricsHistoryProvider {
    func feeHistory(blockCount: Int, newestBlock: Int) async throws -> [ChainMetricPoint]
    func currentBlockNumber() async throws -> Int
}

protocol ChainMetricsProvider: EthereumMetricsProvider, ChainMetricsHistoryProvider {}
