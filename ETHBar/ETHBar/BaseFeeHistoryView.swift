import SwiftUI

struct BaseFeeHistoryView: View {
    let points: [ChainMetricPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Base fee history")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                if !points.isEmpty {
                    Text("\(points.count.formatted()) blocks")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            chart
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
            Canvas { context, size in
                let buckets = Self.buckets(
                    from: points,
                    targetCount: max(1, Int(size.width / 2)) //one bar every 2 pixels
                )
                guard let maxBaseFee = buckets.map(\.peakBaseFeeGwei).max(), //tallest value and scale everything else relative to it
                      maxBaseFee > 0 else {
                    return
                }

                let guideY = size.height * 0.28
                var guide = Path()
                guide.move(to: CGPoint(x: 0, y: guideY))
                guide.addLine(to: CGPoint(x: size.width, y: guideY))
                context.stroke(
                    guide,
                    with: .color(.secondary.opacity(0.16)),
                    lineWidth: 1
                )

                let stepWidth = size.width / CGFloat(buckets.count) //the horizontal slot each bucket gets
                let barWidth = max(1, stepWidth * 0.72) //a little narrower so bars have tiny gaps
                let drawableHeight = max(1, size.height - 4) //leaves a little breathing room

                for (index, bucket) in buckets.enumerated() {
                    let normalizedHeight = bucket.peakBaseFeeGwei / maxBaseFee
                    let barHeight = max(1, drawableHeight * normalizedHeight)
                    //draws each bar
                    let rect = CGRect(
                        x: CGFloat(index) * stepWidth,
                        y: size.height - barHeight,
                        width: barWidth,
                        height: barHeight
                    )

                    context.fill(
                        Path(rect),
                        with: .color(.accentColor.opacity(0.82))
                    )
                }
            }
            .frame(height: 88)
        }
    }

    //takes raw block history and compresses it into chart buckets
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

        let bucketSize = Double(usablePoints.count) / Double(targetCount) //number of blocks per bar

        return (0..<targetCount).compactMap { bucketIndex in
            let startIndex = Int(floor(Double(bucketIndex) * bucketSize))
            let endIndex = min(
                usablePoints.count,
                Int(floor(Double(bucketIndex + 1) * bucketSize))
            )

            guard startIndex < endIndex else {
                return nil
            }

            let peakBaseFee = usablePoints[startIndex..<endIndex] //each bar represents peak base fee TBD if we do this vs like avg or smth
                .map(\.baseFeeGwei)
                .max() ?? 0

            return BaseFeeBucket(peakBaseFeeGwei: peakBaseFee)
        }
    }
}

private struct BaseFeeBucket {
    let peakBaseFeeGwei: Double
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
