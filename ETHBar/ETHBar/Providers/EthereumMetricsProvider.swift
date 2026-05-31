import Foundation

//Purpose: anything that can produce EthereumMetrics can plug into the app.

protocol EthereumMetricsProvider {
    var sourceName: String { get }

    func subscribeToMetrics() -> AsyncThrowingStream<EthereumMetrics, Error>
}
