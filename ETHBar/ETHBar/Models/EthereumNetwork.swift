import Foundation

//defines chain/network config

nonisolated struct EthereumNetwork: Equatable {
    let name: String
    let chainID: Int
    let httpURL: URL
    let webSocketURL: URL
}

extension EthereumNetwork {
    nonisolated static let mainnet = EthereumNetwork(
        name: "Ethereum Mainnet",
        chainID: 1,
        httpURL: URL(string: "https://ethereum-rpc.publicnode.com")!,
        webSocketURL: URL(string: "wss://ethereum-rpc.publicnode.com")!
    )
}
