import SwiftUI

struct GasUsageHistoryView: View {
    let points: [ChainMetricPoint]

    @State private var highlightedBucket: HighlightedGasUsageBucket?
    @State private var selectedWindow: GasUsageHistoryWindow = .twentyFourHours
    @State private var isShowingHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            chart
            legend
        }
        .onChange(of: selectedWindow) {
            highlightedBucket = nil
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label {
                Text("Gas usage")
                    .font(.headline)
                    .fontWeight(.bold)
            } icon: {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.subheadline)
            }
            .foregroundStyle(.primary)

            windowMenu

            helpIcon

            Spacer()

            if let summary {
                GasUsageHeaderStats(summary: summary)
            }
        }
    }

    private var helpIcon: some View {
        Button {
            isShowingHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .help("Explain gas usage signals")
        .accessibilityLabel("Gas usage help")
        .popover(isPresented: $isShowingHelp, arrowEdge: .top) {
            GasUsageHelpPopover()
        }
    }

    private var windowMenu: some View {
        Menu {
            ForEach(GasUsageHistoryWindow.allCases) { window in
                Button {
                    selectedWindow = window
                } label: {
                    if window == selectedWindow {
                        Label(window.label, systemImage: "checkmark")
                    } else {
                        Text(window.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedWindow.label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.primary.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .controlSize(.small)
    }

    @ViewBuilder
    private var chart: some View {
        if visiblePoints.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.secondary.opacity(0.16), lineWidth: 1)

                Text("Loading usage")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 108)
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        drawChart(context: context, size: size)
                    }

                    if let highlightedBucket {
                        GasUsageTooltip(bucket: highlightedBucket.bucket)
                            .position(
                                tooltipPosition(
                                    for: highlightedBucket.position,
                                    size: proxy.size
                                )
                            )
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover(coordinateSpace: .local) { phase in
                    switch phase {
                    case .active(let location):
                        highlightedBucket = highlightedBucket(
                            at: location,
                            size: proxy.size
                        )
                    case .ended:
                        highlightedBucket = nil
                    }
                }
            }
            .frame(height: 108)
        }
    }

    @ViewBuilder
    private var legend: some View {
        if let summary {
            HStack(spacing: 10) {
                GasUsageLegendItem(color: Self.spareColor.opacity(0.82), text: "spare")
                GasUsageLegendItem(color: Self.pressureColor.opacity(0.82), text: "over")
                GasUsageLegendItem(color: Self.hotColor.opacity(0.82), text: "hot")

                Spacer(minLength: 6)

                Text("over \(Self.percentText(summary.aboveTargetShare))")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private var summary: GasUsageSummary? {
        Self.summary(from: visiblePoints)
    }

    private var visiblePoints: [ChainMetricPoint] {
        guard let approximateBlockCount = selectedWindow.approximateBlockCount,
              points.count > approximateBlockCount else {
            return points
        }

        return Array(points.suffix(approximateBlockCount))
    }

    private func drawChart(context: GraphicsContext, size: CGSize) {
        guard let model = chartModel(size: size) else {
            return
        }

        drawBackground(context: context, size: size)
        drawGuides(context: context, size: size)
        drawBars(context: context, size: size, model: model)
        drawHotRail(context: context, size: size, model: model)

        if let highlightedBucket {
            drawHighlight(
                context: context,
                highlightedBucket: highlightedBucket,
                height: size.height
            )
        }
    }

    private func chartModel(size: CGSize) -> GasUsageChartModel? {
        let buckets = Self.buckets(
            from: visiblePoints,
            targetCount: max(1, Int(size.width / 5))
        )

        guard !buckets.isEmpty else {
            return nil
        }

        let stepWidth = size.width / CGFloat(buckets.count)
        let barWidth = max(2, stepWidth * 0.86)

        return GasUsageChartModel(
            buckets: buckets,
            stepWidth: stepWidth,
            barWidth: barWidth
        )
    }

    private func drawBackground(context: GraphicsContext, size: CGSize) {
        let border = Path(
            roundedRect: CGRect(origin: .zero, size: size),
            cornerRadius: 4
        )

        let targetY = Self.targetYPosition(height: size.height)
        let upperZone = CGRect(x: 0, y: 0, width: size.width, height: targetY)
        let lowerZone = CGRect(
            x: 0,
            y: targetY,
            width: size.width,
            height: size.height - targetY
        )

        context.fill(Path(lowerZone), with: .color(Self.spareColor.opacity(0.045)))
        context.fill(Path(upperZone), with: .color(Self.pressureColor.opacity(0.055)))
        context.stroke(
            border,
            with: .color(.secondary.opacity(0.18)),
            lineWidth: 1
        )
    }

    private func drawGuides(context: GraphicsContext, size: CGSize) {
        for ratio in [0.25, 0.75] {
            drawHorizontalGuide(
                context: context,
                y: Self.yPosition(for: ratio, height: size.height),
                width: size.width,
                color: .secondary.opacity(0.1),
                lineWidth: 1
            )
        }

        drawHorizontalGuide(
            context: context,
            y: Self.targetYPosition(height: size.height),
            width: size.width,
            color: .primary.opacity(0.34),
            lineWidth: 1.5
        )
    }

    private func drawHorizontalGuide(
        context: GraphicsContext,
        y: CGFloat,
        width: CGFloat,
        color: Color,
        lineWidth: CGFloat
    ) {
        var guide = Path()
        guide.move(to: CGPoint(x: 0, y: y))
        guide.addLine(to: CGPoint(x: width, y: y))
        context.stroke(guide, with: .color(color), lineWidth: lineWidth)
    }

    private func drawBars(
        context: GraphicsContext,
        size: CGSize,
        model: GasUsageChartModel
    ) {
        let targetY = Self.targetYPosition(height: size.height)

        for (index, bucket) in model.buckets.enumerated() {
            let clampedAverage = min(max(bucket.averageGasRatio, 0), 1)
            let x = CGFloat(index) * model.stepWidth
            let barX = x + ((model.stepWidth - model.barWidth) / 2)
            let averageY = Self.yPosition(for: clampedAverage, height: size.height)
            let rectY = min(targetY, averageY)
            let rectHeight = max(1, abs(targetY - averageY))
            let rect = CGRect(
                x: barX,
                y: rectY,
                width: model.barWidth,
                height: rectHeight
            )
            let opacity = 0.48 + (min(abs(clampedAverage - Self.targetGasRatio) / Self.targetGasRatio, 1) * 0.38)
            let fillColor: Color
            if bucket.pointCount == 1, clampedAverage >= Self.hotGasRatio {
                fillColor = Self.hotColor.opacity(0.86)
            } else {
                fillColor = clampedAverage >= Self.targetGasRatio
                    ? Self.pressureColor.opacity(opacity)
                    : Self.spareColor.opacity(opacity)
            }

            context.fill(
                Path(rect),
                with: .color(fillColor)
            )
        }
    }

    private func drawHotRail(
        context: GraphicsContext,
        size: CGSize,
        model: GasUsageChartModel
    ) {
        for (index, bucket) in model.buckets.enumerated() {
            guard bucket.pointCount > 1,
                  bucket.hotBlockShare > 0 else {
                continue
            }

            let x = CGFloat(index) * model.stepWidth
            let barX = x + ((model.stepWidth - model.barWidth) / 2)
            let railHeight = max(2, 3 + (bucket.hotBlockShare * 10))
            let railRect = CGRect(
                x: barX,
                y: 2,
                width: model.barWidth,
                height: railHeight
            )

            context.fill(
                Path(railRect),
                with: .color(Self.hotColor.opacity(0.42 + (bucket.hotBlockShare * 0.5)))
            )
        }
    }

    private func highlightedBucket(
        at location: CGPoint,
        size: CGSize
    ) -> HighlightedGasUsageBucket? {
        guard let model = chartModel(size: size) else {
            return nil
        }

        let clampedX = min(max(location.x, 0), size.width - 1)
        let bucketIndex = min(
            model.buckets.count - 1,
            max(0, Int(clampedX / model.stepWidth))
        )
        let bucket = model.buckets[bucketIndex]
        let x = CGFloat(bucketIndex) * model.stepWidth + (model.stepWidth / 2)
        let y = Self.yPosition(for: bucket.averageGasRatio, height: size.height)

        return HighlightedGasUsageBucket(
            bucket: bucket,
            position: CGPoint(x: x, y: y)
        )
    }

    private func tooltipPosition(
        for point: CGPoint,
        size: CGSize
    ) -> CGPoint {
        let tooltipWidth: CGFloat = 96
        let tooltipHeight: CGFloat = 56
        let x = min(
            max(point.x, tooltipWidth / 2),
            size.width - (tooltipWidth / 2)
        )
        let y = min(
            max(tooltipHeight / 2, point.y - 20),
            size.height - (tooltipHeight / 2)
        )

        return CGPoint(x: x, y: y)
    }

    private func drawHighlight(
        context: GraphicsContext,
        highlightedBucket: HighlightedGasUsageBucket,
        height: CGFloat
    ) {
        var verticalGuide = Path()
        verticalGuide.move(to: CGPoint(x: highlightedBucket.position.x, y: 0))
        verticalGuide.addLine(to: CGPoint(x: highlightedBucket.position.x, y: height))
        context.stroke(
            verticalGuide,
            with: .color(.red.opacity(0.22)),
            lineWidth: 1
        )

    }

    private static func yPosition(for ratio: Double, height: CGFloat) -> CGFloat {
        let clampedRatio = min(max(ratio, 0), 1)
        return height - (height * clampedRatio)
    }

    private static func targetYPosition(height: CGFloat) -> CGFloat {
        yPosition(for: targetGasRatio, height: height)
    }

    private static func summary(from points: [ChainMetricPoint]) -> GasUsageSummary? {
        let gasRatios = points
            .map(\.gasUsedRatio)
            .filter { $0 >= 0 }

        guard let latestGasRatio = gasRatios.last,
              !gasRatios.isEmpty else {
            return nil
        }

        let averageGasRatio = gasRatios.reduce(0, +) / Double(gasRatios.count)
        let aboveTargetCount = gasRatios.filter { $0 > targetGasRatio }.count
        let hotBlockCount = gasRatios.filter { $0 >= hotGasRatio }.count

        return GasUsageSummary(
            latestGasRatio: latestGasRatio,
            averageGasRatio: averageGasRatio,
            aboveTargetShare: Double(aboveTargetCount) / Double(gasRatios.count),
            hotBlockShare: Double(hotBlockCount) / Double(gasRatios.count)
        )
    }

    private static func buckets(
        from points: [ChainMetricPoint],
        targetCount: Int
    ) -> [GasUsageBucket] {
        let usablePoints = points.filter { $0.gasUsedRatio >= 0 }
        guard !usablePoints.isEmpty, targetCount > 0 else {
            return []
        }

        guard usablePoints.count > targetCount else {
            return usablePoints.map { point in
                GasUsageBucket(
                    averageGasRatio: point.gasUsedRatio,
                    aboveTargetShare: point.gasUsedRatio > targetGasRatio ? 1 : 0,
                    hotBlockShare: point.gasUsedRatio >= hotGasRatio ? 1 : 0,
                    pointCount: 1
                )
            }
        }

        let bucketSize = Double(usablePoints.count) / Double(targetCount)

        return (0..<targetCount).compactMap { bucketIndex in
            let startIndex = Int(floor(Double(bucketIndex) * bucketSize))
            let endIndex = min(
                usablePoints.count,
                Int(floor(Double(bucketIndex + 1) * bucketSize))
            )

            guard startIndex < endIndex else {
                return nil
            }

            let ratios = usablePoints[startIndex..<endIndex].map(\.gasUsedRatio)
            let average = ratios.reduce(0, +) / Double(ratios.count)
            let aboveTargetCount = ratios.filter { $0 > targetGasRatio }.count
            let hotBlockCount = ratios.filter { $0 >= hotGasRatio }.count

            return GasUsageBucket(
                averageGasRatio: average,
                aboveTargetShare: Double(aboveTargetCount) / Double(ratios.count),
                hotBlockShare: Double(hotBlockCount) / Double(ratios.count),
                pointCount: ratios.count
            )
        }
    }

    private static func percentText(_ ratio: Double) -> String {
        ratio.formatted(.percent.precision(.fractionLength(0...1)))
    }

    private static let targetGasRatio = 0.5
    private static let hotGasRatio = 0.9
    fileprivate static let spareColor = Color(red: 0.17, green: 0.78, blue: 0.9)
    fileprivate static let pressureColor = Color(red: 1, green: 0.55, blue: 0.18)
    fileprivate static let hotColor = Color(red: 1, green: 0.18, blue: 0.42)
    private static let helpText = """
    spare: average gas usage below Ethereum's 50% target.
    over: average gas usage above the 50% target.
    hot: share of blocks at 90%+ gas usage.
    """
}

private struct GasUsageBucket {
    let averageGasRatio: Double
    let aboveTargetShare: Double
    let hotBlockShare: Double
    let pointCount: Int
}

private struct GasUsageChartModel {
    let buckets: [GasUsageBucket]
    let stepWidth: CGFloat
    let barWidth: CGFloat
}

private struct HighlightedGasUsageBucket {
    let bucket: GasUsageBucket
    let position: CGPoint
}

private struct GasUsageSummary {
    let latestGasRatio: Double
    let averageGasRatio: Double
    let aboveTargetShare: Double
    let hotBlockShare: Double
}

private enum GasUsageHistoryWindow: CaseIterable, Identifiable {
    case sevenDays
    case twentyFourHours
    case sixHours
    case oneHour
    case thirtyMinutes
    case fiveMinutes

    private static let approximateBlocksPerHour = 300

    var id: Self {
        self
    }

    var label: String {
        switch self {
        case .sevenDays:
            "7d"
        case .twentyFourHours:
            "24h"
        case .sixHours:
            "6h"
        case .oneHour:
            "1h"
        case .thirtyMinutes:
            "30m"
        case .fiveMinutes:
            "5m"
        }
    }

    var approximateBlockCount: Int? {
        switch self {
        case .sevenDays:
            nil
        case .twentyFourHours:
            Self.approximateBlocksPerHour * 24
        case .sixHours:
            Self.approximateBlocksPerHour * 6
        case .oneHour:
            Self.approximateBlocksPerHour
        case .thirtyMinutes:
            Self.approximateBlocksPerHour / 2
        case .fiveMinutes:
            Self.approximateBlocksPerHour / 12
        }
    }
}

private struct GasUsageHeaderStats: View {
    let summary: GasUsageSummary

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("now")
                    .font(.caption2)
                    .foregroundStyle(.primary)

                Text(format(summary.latestGasRatio))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                compactStat(label: "avg", value: summary.averageGasRatio)
                compactStat(label: "hot", value: summary.hotBlockShare)
            }
        }
    }

    private func compactStat(label: String, value: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(format(value))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func format(_ ratio: Double) -> String {
        ratio.formatted(.percent.precision(.fractionLength(0...1)))
    }
}

private struct GasUsageLegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct GasUsageHelpPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GasUsageHelpRow(
                color: GasUsageHistoryView.spareColor,
                label: "spare",
                detail: "Avg usage below Ethereum's 50% target."
            )
            GasUsageHelpRow(
                color: GasUsageHistoryView.pressureColor,
                label: "over",
                detail: "Avg usage above the 50% target."
            )
            GasUsageHelpRow(
                color: GasUsageHistoryView.hotColor,
                label: "hot",
                detail: "Share of blocks at 90%+ usage."
            )
        }
        .padding(10)
        .frame(width: 220, alignment: .leading)
    }
}

private struct GasUsageHelpRow: View {
    let color: Color
    let label: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle()
                .fill(color.opacity(0.86))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GasUsageTooltip: View {
    let bucket: GasUsageBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if bucket.pointCount > 1 {
                stat(label: "avg", value: bucket.averageGasRatio)
                stat(label: "over", value: bucket.aboveTargetShare)
                stat(label: "hot", value: bucket.hotBlockShare)
            } else {
                stat(label: "gas", value: bucket.averageGasRatio)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(.red.opacity(0.42), lineWidth: 1)
        }
    }

    private func stat(label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)

            Text(value.formatted(.percent.precision(.fractionLength(0...1))))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .font(.caption2)
    }
}

struct GasUsageHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        GasUsageHistoryView(points: previewPoints)
            .padding()
            .frame(width: 320)
    }

    private static var previewPoints: [ChainMetricPoint] {
        (0..<720).map { index in
            let wave = sin(Double(index) / 18) * 0.22
            let pulse = index.isMultiple(of: 71) ? 0.38 : 0
            let quiet = index.isMultiple(of: 29) ? -0.2 : 0
            let ratio = min(max(0.08, 0.48 + wave + pulse + quiet), 0.98)

            return ChainMetricPoint(
                blockNumber: index,
                timestamp: nil,
                baseFeeGwei: 18,
                gasUsedRatio: ratio
            )
        }
    }
}
