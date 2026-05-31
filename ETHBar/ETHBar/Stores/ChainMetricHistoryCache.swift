import Foundation

actor ChainMetricHistoryCache {
    static let defaultRetainedBlockCount = 50_400 //7 days * 24h * 60m * 60s / ~12s per block = 50,400 blocks


    private let chainID: Int
    private let networkName: String
    private let fileURL: URL
    private let retainedBlockCount: Int
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        chainID: Int,
        networkName: String,
        retainedBlockCount: Int = ChainMetricHistoryCache.defaultRetainedBlockCount,
        fileURL: URL? = nil
    ) {
        self.chainID = chainID
        self.networkName = networkName
        self.retainedBlockCount = retainedBlockCount
        self.fileURL = fileURL ?? Self.defaultFileURL(chainID: chainID)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    func loadHistory() throws -> ChainMetricHistory {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ChainMetricHistory(chainID: chainID, networkName: networkName, points: [])
        }

        let data = try Data(contentsOf: fileURL)
        let history = try decoder.decode(ChainMetricHistory.self, from: data)
        return Self.normalized(history, retainedBlockCount: retainedBlockCount)
    }

    func saveHistory(_ history: ChainMetricHistory) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(Self.normalized(history, retainedBlockCount: retainedBlockCount))
        try data.write(to: fileURL, options: [.atomic])
    }

    func mergedHistory(
        existingHistory: ChainMetricHistory,
        newPoints: [ChainMetricPoint]
    ) -> ChainMetricHistory {
        let mergedHistory = ChainMetricHistory(
            chainID: existingHistory.chainID,
            networkName: existingHistory.networkName,
            points: existingHistory.points + newPoints
        )
        return Self.normalized(mergedHistory, retainedBlockCount: retainedBlockCount)
    }

    private nonisolated static func normalized(
        _ history: ChainMetricHistory,
        retainedBlockCount: Int
    ) -> ChainMetricHistory {
        let pointsByBlock = Dictionary(history.points.map { ($0.blockNumber, $0) }, uniquingKeysWith: { _, newest in newest })
        let sortedPoints = pointsByBlock.values.sorted { $0.blockNumber < $1.blockNumber }
        let retainedPoints = Self.retainedPoints(sortedPoints, retainedBlockCount: retainedBlockCount)

        return ChainMetricHistory(
            chainID: history.chainID,
            networkName: history.networkName,
            points: retainedPoints
        )
    }

    private nonisolated static func retainedPoints(
        _ sortedPoints: [ChainMetricPoint],
        retainedBlockCount: Int
    ) -> [ChainMetricPoint] {
        guard retainedBlockCount > 0,
              let latestBlockNumber = sortedPoints.last?.blockNumber else {
            return sortedPoints
        }

        let oldestRetainedBlockNumber = latestBlockNumber - retainedBlockCount + 1
        return sortedPoints.filter { $0.blockNumber >= oldestRetainedBlockNumber }
    }

    private nonisolated static func defaultFileURL(chainID: Int) -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let baseURL = applicationSupportURL ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("ETHBar", isDirectory: true)
            .appendingPathComponent("history-chain-\(chainID).json")
    }
}
