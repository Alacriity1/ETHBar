import Foundation

struct EthereumHTTPRPCClient {
    let endpointURL: URL
    var session: URLSession = .shared

    func feeHistory(blockCount: Int, newestBlock: Int) async throws -> EthereumFeeHistory {
        let request = JSONRPCRequest(
            method: "eth_feeHistory",
            params: [
                .string(Self.hexQuantity(blockCount)), //blockcount
                .string(Self.hexQuantity(newestBlock)), //newestBlock
                .numberArray([]) //rewardPercentiles [optional]
            ]
        )

        let response: JSONRPCResponse<EthereumFeeHistoryResponse> = try await send(request)
        return try response.requiredResult().history()
    }

    func blockNumber() async throws -> Int {
        let request = JSONRPCRequest(
            method: "eth_blockNumber",
            params: []
        )

        let response: JSONRPCResponse<String> = try await send(request)
        return try Self.hexQuantityToInt(response.requiredResult())
    }

    private func send<Response: Decodable>(_ request: JSONRPCRequest) async throws -> Response {
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData

        if let requestText = String(data: requestData, encoding: .utf8) {
            ETHBarLog.debug("RPC request: \(requestText)", category: .http)
        }

        let (data, urlResponse) = try await session.data(for: urlRequest)

        guard let httpResponse = urlResponse as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw EthereumHTTPRPCError.invalidHTTPResponse
        }

          //Note for self, maybe use 'baseFeePerBlobGas' and 'blobGasUsedRatio'  from response or blobs in general?
//        if let responseText = String(data: data, encoding: .utf8) {
//            ETHBarLog.debug("RPC response: \(responseText)", category: .http)
//        }

        let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
        return decodedResponse
    }

    private nonisolated static func hexQuantity(_ value: Int) -> String {
        "0x" + String(value, radix: 16)
    }

    private nonisolated static func hexQuantityToInt(_ value: String) throws -> Int {
        let hex = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value

        guard let parsed = UInt64(hex, radix: 16) else {
            throw EthereumHTTPRPCError.invalidHex(value)
        }

        return Int(parsed)
    }
}

struct EthereumFeeHistory: Equatable {
    let oldestBlock: Int
    let baseFeePerGasGwei: [Double]
    let gasUsedRatio: [Double]

    var blockCount: Int {
        gasUsedRatio.count
    }

    func chainMetricPoints() -> [ChainMetricPoint] {
        gasUsedRatio.indices.map { index in
            ChainMetricPoint(
                blockNumber: oldestBlock + index,
                timestamp: nil,
                baseFeeGwei: baseFeePerGasGwei[index],
                gasUsedRatio: gasUsedRatio[index]
            )
        }
    }
}

private struct JSONRPCRequest: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let params: [JSONRPCParameter]
    let id = 1
}

private enum JSONRPCParameter: Encodable {
    case string(String)
    case numberArray([Double])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .numberArray(let values):
            try container.encode(values)
        }
    }
}

private struct JSONRPCResponse<Result: Decodable>: Decodable {
    let result: Result?
    let error: JSONRPCErrorResponse?

    func requiredResult() throws -> Result {
        if let result {
            return result
        }

        if let error {
            throw EthereumHTTPRPCError.jsonRPCError(code: error.code, message: error.message)
        }

        throw EthereumHTTPRPCError.missingResult
    }
}

private struct JSONRPCErrorResponse: Decodable {
    let code: Int
    let message: String
}

private struct EthereumFeeHistoryResponse: Decodable {
    let oldestBlock: String
    let baseFeePerGas: [String]
    let gasUsedRatio: [Double]

    func history() throws -> EthereumFeeHistory {
        let oldestBlock = try Self.hexToUInt64(oldestBlock)
        let baseFeePerGasGwei = try baseFeePerGas.map { try Double(Self.hexToUInt64($0)) / 1e9 }

        guard baseFeePerGasGwei.count >= gasUsedRatio.count else {
            throw EthereumHTTPRPCError.invalidFeeHistoryResponse
        }

        return EthereumFeeHistory(
            oldestBlock: Int(oldestBlock),
            baseFeePerGasGwei: Array(baseFeePerGasGwei.prefix(gasUsedRatio.count)),
            gasUsedRatio: gasUsedRatio
        )
    }

    private static func hexToUInt64(_ value: String) throws -> UInt64 {
        let hex = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value

        guard let parsed = UInt64(hex, radix: 16) else {
            throw EthereumHTTPRPCError.invalidHex(value)
        }

        return parsed
    }
}

enum EthereumHTTPRPCError: LocalizedError {
    case invalidHTTPResponse
    case invalidFeeHistoryResponse
    case invalidHex(String)
    case jsonRPCError(code: Int, message: String)
    case missingResult

    var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            "The HTTP RPC endpoint returned an invalid response."
        case .invalidFeeHistoryResponse:
            "The HTTP RPC endpoint returned an invalid fee history response."
        case .invalidHex(let value):
            "The HTTP RPC endpoint returned an invalid hex quantity: \(value)."
        case .jsonRPCError(let code, let message):
            "The HTTP RPC endpoint returned JSON-RPC error \(code): \(message)."
        case .missingResult:
            "The HTTP RPC endpoint response did not include a result."
        }
    }
}
