import Foundation

//defines chain/network config

struct EthereumNetwork: Equatable {
    let name: String
    let chainID: Int
    let rpcURL: URL
    let webSocketURL: URL
}

extension EthereumNetwork {
    static let mainnet = EthereumNetwork(
        name: "Ethereum Mainnet",
        chainID: 1,
        rpcURL: URL(string: "https://ethereum-rpc.publicnode.com")!,
        webSocketURL: URL(string: "wss://ethereum-rpc.publicnode.com")!
    )
}
