import SwiftUI

struct BaseFeeHistoryView: View {
    let points: [ChainMetricPoint]

    @State private var highlightedBucket: HighlightedBaseFeeBucket?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            chart
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Base fee history")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Spacer()

            if let summary {
                Text(
                    "peak \(formatGwei(summary.peakBaseFeeGwei))  avg \(formatGwei(summary.averageBaseFeeGwei))"
                )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        if points.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.secondary.opacity(0.16), lineWidth: 1)

                Text("Loading history")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 88)
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        drawChart(context: context, size: size)
                    }

                    if let highlightedBucket {
                        BaseFeeTooltip(value: highlightedBucket.peakBaseFeeGwei)
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
            .frame(height: 96)
        }
    }

    private var summary: BaseFeeSummary? {
        Self.summary(from: points)
    }

    private func drawChart(context: GraphicsContext, size: CGSize) {
        guard let model = chartModel(size: size) else {
            return
        }

        drawBorder(context: context, size: size)
        drawGuides(
            context: context,
            size: size,
            scaleMax: model.scaleMax
        )
        drawBars(
            context: context,
            size: size,
            model: model
        )
    }

    private func chartModel(size: CGSize) -> BaseFeeChartModel? {
        let buckets = Self.buckets(
            from: points,
            targetCount: max(1, Int(size.width / 2))
        )

        guard let peakBaseFee = buckets.map(\.peakBaseFeeGwei).max(),
              peakBaseFee > 0 else {
            return nil
        }

        let scaleMax = Self.chartScaleMax(for: peakBaseFee)
        let stepWidth = size.width / CGFloat(buckets.count)
        let barWidth = max(1, stepWidth * 0.72)

        return BaseFeeChartModel(
            buckets: buckets,
            scaleMax: scaleMax,
            stepWidth: stepWidth,
            barWidth: barWidth
        )
    }

    private func drawBorder(context: GraphicsContext, size: CGSize) {
        let border = Path(
            roundedRect: CGRect(origin: .zero, size: size),
            cornerRadius: 4
        )

        context.stroke(
            border,
            with: .color(.secondary.opacity(0.18)),
            lineWidth: 1
        )
    }

    private func drawGuides(
        context: GraphicsContext,
        size: CGSize,
        scaleMax: Double
    ) {
        for value in [scaleMax * 0.66, scaleMax * 0.33] {
            let y = Self.yPosition(for: value, scaleMax: scaleMax, height: size.height)

            var guide = Path()
            guide.move(to: CGPoint(x: 0, y: y))
            guide.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(
                guide,
                with: .color(.secondary.opacity(0.12)),
                lineWidth: 1
            )
        }
    }

    private func drawBars(
        context: GraphicsContext,
        size: CGSize,
        model: BaseFeeChartModel
    ) {
        let drawableHeight = max(1, size.height - 4)
        var outline = Path()

        for (index, bucket) in model.buckets.enumerated() {
            let normalizedHeight = bucket.peakBaseFeeGwei / model.scaleMax
            let barHeight = max(1, drawableHeight * normalizedHeight)
            let x = CGFloat(index) * model.stepWidth
            let topY = size.height - barHeight
            let rect = CGRect(
                x: x,
                y: topY,
                width: model.barWidth,
                height: barHeight
            )

            context.fill(
                Path(rect),
                with: .color(.accentColor.opacity(0.78))
            )

            let outlinePoint = CGPoint(x: x + (model.barWidth / 2), y: topY)
            if index == 0 {
                outline.move(to: outlinePoint)
            } else {
                outline.addLine(to: outlinePoint)
            }
        }

        context.stroke(
            outline,
            with: .color(.primary.opacity(0.54)),
            lineWidth: 1
        )

        if let highlightedBucket {
            drawHighlight(
                context: context,
                highlightedBucket: highlightedBucket,
                height: size.height
            )
        }
    }

    private func formatGwei(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...2)))) gwei"
    }

    private func highlightedBucket(
        at location: CGPoint,
        size: CGSize
    ) -> HighlightedBaseFeeBucket? {
        guard let model = chartModel(size: size) else {
            return nil
        }

        let clampedX = min(max(location.x, 0), size.width - 1)
        let bucketIndex = min(
            model.buckets.count - 1,
            max(0, Int(clampedX / model.stepWidth))
        )
        let bucket = model.buckets[bucketIndex]
        let normalizedHeight = bucket.peakBaseFeeGwei / model.scaleMax
        let drawableHeight = max(1, size.height - 4)
        let barHeight = max(1, drawableHeight * normalizedHeight)

        return HighlightedBaseFeeBucket(
            peakBaseFeeGwei: bucket.peakBaseFeeGwei,
            position: CGPoint(
                x: CGFloat(bucketIndex) * model.stepWidth + (model.barWidth / 2),
                y: size.height - barHeight
            )
        )
    }

    private func tooltipPosition(
        for point: CGPoint,
        size: CGSize
    ) -> CGPoint {
        let tooltipWidth: CGFloat = 76
        let tooltipHeight: CGFloat = 28
        let x = min(
            max(point.x, tooltipWidth / 2),
            size.width - (tooltipWidth / 2)
        )
        let y = max(tooltipHeight / 2, point.y - 18)

        return CGPoint(x: x, y: y)
    }

    private func drawHighlight(
        context: GraphicsContext,
        highlightedBucket: HighlightedBaseFeeBucket,
        height: CGFloat
    ) {
        var verticalGuide = Path()
        verticalGuide.move(to: CGPoint(x: highlightedBucket.position.x, y: 0))
        verticalGuide.addLine(to: CGPoint(x: highlightedBucket.position.x, y: height))
        context.stroke(
            verticalGuide,
            with: .color(.red.opacity(0.24)),
            lineWidth: 1
        )

        let dotRect = CGRect(
            x: highlightedBucket.position.x - 2,
            y: highlightedBucket.position.y - 2,
            width: 4,
            height: 4
        )
        context.fill(
            Path(ellipseIn: dotRect),
            with: .color(.red)
        )
    }

    private static func yPosition(
        for value: Double,
        scaleMax: Double,
        height: CGFloat
    ) -> CGFloat {
        guard scaleMax > 0 else {
            return height
        }

        let clampedValue = min(max(value, 0), scaleMax)
        let normalized = clampedValue / scaleMax
        return height - (height * normalized)
    }

    private static func chartScaleMax(for peakValue: Double) -> Double {
        peakValue / 0.86 //86% of vertical window height
    }

    private static func summary(from points: [ChainMetricPoint]) -> BaseFeeSummary? {
        let fees = points
            .map(\.baseFeeGwei)
            .filter { $0 > 0 }

        guard let peakBaseFeeGwei = fees.max(), !fees.isEmpty else {
            return nil
        }

        let averageBaseFeeGwei = fees.reduce(0, +) / Double(fees.count)

        return BaseFeeSummary(
            peakBaseFeeGwei: peakBaseFeeGwei,
            averageBaseFeeGwei: averageBaseFeeGwei
        )
    }

    private static func buckets(
        from points: [ChainMetricPoint],
        targetCount: Int
    ) -> [BaseFeeBucket] {
        let usablePoints = points.filter { $0.baseFeeGwei > 0 }
        guard !usablePoints.isEmpty, targetCount > 0 else {
            return []
        }

        guard usablePoints.count > targetCount else {
            return usablePoints.map { point in
                BaseFeeBucket(peakBaseFeeGwei: point.baseFeeGwei)
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

            let peakBaseFee = usablePoints[startIndex..<endIndex]
                .map(\.baseFeeGwei)
                .max() ?? 0

            return BaseFeeBucket(peakBaseFeeGwei: peakBaseFee)
        }
    }
}

private struct BaseFeeBucket {
    let peakBaseFeeGwei: Double
}

private struct BaseFeeChartModel {
    let buckets: [BaseFeeBucket]
    let scaleMax: Double
    let stepWidth: CGFloat
    let barWidth: CGFloat
}

private struct HighlightedBaseFeeBucket {
    let peakBaseFeeGwei: Double
    let position: CGPoint
}

private struct BaseFeeSummary {
    let peakBaseFeeGwei: Double
    let averageBaseFeeGwei: Double
}

private struct BaseFeeTooltip: View {
    let value: Double

    var body: some View {
        Text("\(value.formatted(.number.precision(.fractionLength(0...3)))) gwei")
            .font(.caption2)
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.red.opacity(0.42), lineWidth: 1)
            }
    }
}

struct BaseFeeHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        BaseFeeHistoryView(points: previewPoints)
            .padding()
            .frame(width: 320)
    }

    private static var previewPoints: [ChainMetricPoint] {
        (0..<420).map { index in
            let wave = sin(Double(index) / 19) * 8
            let spike = index.isMultiple(of: 83) ? 28.0 : 0
            let noise = Double(index % 11) * 0.35

            return ChainMetricPoint(
                blockNumber: index,
                timestamp: nil,
                baseFeeGwei: max(0.5, 12 + wave + spike + noise),
                gasUsedRatio: 0.5
            )
        }
    }
}
