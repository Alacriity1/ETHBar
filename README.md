# ETHBar

ETHBar is a tiny macOS menu bar app for keeping a few live Ethereum Mainnet metrics visible without opening a block explorer.

This repo started as an Ethereum-focused experiment inspired by [CodexBar](https://github.com/steipete/CodexBar/), a minimal macOS menu bar app pattern with no Dock icon and a compact popover UI.

![ETHBar screenshot](public/ETHBar.png)

## Current Version

The current working version uses PublicNode's public Ethereum Mainnet RPC/WebSocket endpoint. It subscribes to new block headers and displays:

- Base fee
- Latest block number
- Gas used percentage
- Last updated time

## Flow

```text
ContentView
  observes
EthereumMetricsStore
  starts
EthereumMetricsProvider
  implemented by
PublicRPCMetricsProvider
  uses
EthereumBlockSubscriptionClient
  subscribes to
PublicNode WebSocket newHeads
```

1. `ETHBarApp` creates a shared `EthereumMetricsStore`.
2. The store starts live updates during initialization.
3. `PublicRPCMetricsProvider` creates an `EthereumBlockSubscriptionClient` for PublicNode's WebSocket endpoint.
4. The client sends an `eth_subscribe` request for `newHeads`.
5. Each block header is decoded into `EthereumBlockHeader`.
6. The provider maps the header into `EthereumMetrics`.
7. The store publishes the latest metrics, which updates the menu bar title and SwiftUI popover.
