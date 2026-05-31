import Foundation

//low-level JSON-RPC caller
//Purpose: isolate raw HTTP/JSON-RPC mechanics in one place. The UI and store should never manually build JSON-RPC payloads.

struct EthereumRPCClient {
    let endpointURL: URL
    var session: URLSession = .shared

    func gasPriceWei() async throws -> UInt64 {
        let result: String = try await call(method: "eth_gasPrice")
        return try Self.hexToUInt64(result)
    }

    func blockNumber() async throws -> Int {
        let result: String = try await call(method: "eth_blockNumber")
        return Int(try Self.hexToUInt64(result))
    }

    private func call(method: String) async throws -> String {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(JSONRPCRequest(method: method))

        debugLog("RPC request \(method) -> \(endpointURL.absoluteString)")
        if let body = request.httpBody, let bodyText = String(data: body, encoding: .utf8) {
            debugLog("RPC request body: \(bodyText)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            debugLog("RPC bad HTTP response for \(method): \(response)")
            throw EthereumRPCError.badHTTPResponse
        }

        debugLog("RPC status \(method): \(httpResponse.statusCode)")
        if let responseText = String(data: data, encoding: .utf8) {
            debugLog("RPC raw response \(method): \(responseText)")
        }

        let rpcResponse = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

        if let error = rpcResponse.error {
            debugLog("RPC error \(method): \(error.message)")
            throw EthereumRPCError.rpcError(error.message)
        }

        guard let result = rpcResponse.result else {
            debugLog("RPC missing result for \(method)")
            throw EthereumRPCError.missingResult
        }

        debugLog("RPC parsed result \(method): \(result)")
        return result
    }

    private static func hexToUInt64(_ value: String) throws -> UInt64 {
        let hex = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value

        guard let parsed = UInt64(hex, radix: 16) else {
            throw EthereumRPCError.invalidHex(value)
        }

        return parsed
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[ETHBar][RPC] \(message)")
        #endif
    }
}

private struct JSONRPCRequest: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let params: [String] = []
    let id = 1
}

private struct JSONRPCResponse: Decodable {
    let result: String?
    let error: JSONRPCErrorResponse?
}

private struct JSONRPCErrorResponse: Decodable {
    let message: String
}

enum EthereumRPCError: LocalizedError {
    case badHTTPResponse
    case invalidHex(String)
    case missingResult
    case rpcError(String)

    var errorDescription: String? {
        switch self {
        case .badHTTPResponse:
            "The RPC endpoint returned an unsuccessful HTTP response."
        case .invalidHex(let value):
            "The RPC endpoint returned an invalid hex value: \(value)."
        case .missingResult:
            "The RPC endpoint did not include a result."
        case .rpcError(let message):
            "The RPC endpoint returned an error: \(message)."
        }
    }
}
