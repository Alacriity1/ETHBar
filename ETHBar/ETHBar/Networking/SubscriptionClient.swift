import Foundation

struct SubscriptionClient {
    let endpointURL: URL
    var session: URLSession = .shared

    func blockHeaders() -> AsyncThrowingStream<EthereumBlockHeader, Error> {
        AsyncThrowingStream { continuation in
            let webSocketTask = session.webSocketTask(with: endpointURL)

            let receiveTask = Task {
                do {
                    webSocketTask.resume()

                    let request = JSONRPCSubscriptionRequest()
                    let requestData = try JSONEncoder().encode(request)
                    let requestText = String(data: requestData, encoding: .utf8) ?? ""

//                    ETHBarLog.debug("WS connecting -> \(endpointURL.absoluteString)", category: .webSocket, separated: true)
//                    ETHBarLog.debug("WS subscribe body: \(requestText)", category: .webSocket, separated: true)

                    try await webSocketTask.send(.string(requestText))

                    while !Task.isCancelled {
                        let message = try await webSocketTask.receive()
                        let text = try Self.text(from: message)

//                        ETHBarLog.debug("WS raw message: \(text)", category: .webSocket, separated: true) // First response is a generic confirmation result data

                        if let blockHeader = try Self.blockHeader(from: text) {
//                            ETHBarLog.debug("WS new block: \(blockHeader.number)", category: .webSocket, separated: true)
                            continuation.yield(blockHeader) // consumed by the for try await loop in PublicNodeMetricsProvider.swift
                        }
                    }
                } catch {
                    ETHBarLog.debug("WS failed: \(error.localizedDescription)", category: .webSocket, separated: true)
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                receiveTask.cancel()
                webSocketTask.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    private nonisolated static func text(from message: URLSessionWebSocketTask.Message) throws -> String {
        switch message {
        case .string(let text):
            return text
        case .data(let data):
            return String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            throw EthereumBlockSubscriptionError.unsupportedMessage
        }
    }

    private static func blockHeader(from text: String) throws -> EthereumBlockHeader? {
        let data = Data(text.utf8)
        let notification = try JSONDecoder().decode(JSONRPCSubscriptionNotification.self, from: data)

        guard notification.method == "eth_subscription",
              let result = notification.params?.result,
              let blockNumberHex = result.number else {
            return nil
        }

        let baseFeePerGasWei = try result.baseFeePerGas.map(hexToUInt64) ?? 0
        let gasLimit = try result.gasLimit.map(hexToUInt64) ?? 0
        let gasUsed = try result.gasUsed.map(hexToUInt64) ?? 0
        let timestamp = try result.timestamp.map(hexToUInt64) ?? 0

        return EthereumBlockHeader(
            number: Int(try hexToUInt64(blockNumberHex)),
            baseFeePerGasGwei: Double(baseFeePerGasWei) / 1e9, //maybe properly handle wei vs gwei if its not large enough (for like L2s im thinking)
            gasUsed: Int(gasUsed),
            gasLimit: Int(gasLimit),
            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp)) //maybe jusut do raw timestampo number?
        )
    }

    private nonisolated static func hexToUInt64(_ value: String) throws -> UInt64 {
        let hex = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value

        guard let parsed = UInt64(hex, radix: 16) else {
            throw EthereumBlockSubscriptionError.invalidHex(value)
        }

        return parsed
    }
}

private struct JSONRPCSubscriptionRequest: Encodable {
    let jsonrpc = "2.0"
    let method = "eth_subscribe"
    let params = ["newHeads"]
    let id = 1
}

private struct JSONRPCSubscriptionNotification: Decodable {
    let method: String?
    let params: JSONRPCSubscriptionParams?
}

private struct JSONRPCSubscriptionParams: Decodable {
    let result: JSONRPCBlockHeader
}

private struct JSONRPCBlockHeader: Decodable {
    let number: String?
    let baseFeePerGas: String?
    let gasUsed: String?
    let gasLimit: String?
    let timestamp: String?
}

enum EthereumBlockSubscriptionError: LocalizedError {
    case invalidHex(String)
    case unsupportedMessage

    var errorDescription: String? {
        switch self {
        case .invalidHex(let value):
            "The WebSocket endpoint returned an invalid block number: \(value)."
        case .unsupportedMessage:
            "The WebSocket endpoint returned an unsupported message type."
        }
    }
}
