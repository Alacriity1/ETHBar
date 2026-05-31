import Foundation

//defines chain/network config

struct EthereumNetwork: Equatable {
    let name: String
    let chainID: Int
    let webSocketURL: URL
}

extension EthereumNetwork {
    static let mainnet = EthereumNetwork(
        name: "Ethereum Mainnet",
        chainID: 1,
        webSocketURL: URL(string: "wss://ethereum-rpc.publicnode.com")!
    )
}
