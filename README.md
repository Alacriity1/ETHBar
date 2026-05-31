# ETHBar

We want to using this Codex bar repo, an example kind of transformed and make our own but for like Ethereum and Blockchain so we can kind of track current gas usage, gas price transaction count, or transaction count per second , and general metrics of that nature so that we can have that as a kind of OS integrated app like this codex bar so something like below: 
: https://github.com/steipete/CodexBar/

That CodexBar repo does this "Tiny macOS 14+ menu bar app that keeps AI coding-provider limits visible and shows when each window resets. Codex, Claude, Cursor, Gemini, Copilot, z.ai, Kiro, Vertex AI, Augment, OpenRouter, Codebuff, Command Code, and many newer coding providers. One status item per provider, or Merge Icons mode with a provider switcher. No Dock icon, minimal UI, dynamic bar icons."

Example image of codex Bar in PUBLIC folder


The flow is:
ContentView
  observes
EthereumMetricsStore
  calls
EthereumMetricsProvider
  implemented by
PublicRPCMetricsProvider
  uses
EthereumRPCClient
  fetches from
PublicNode JSON-RPC
