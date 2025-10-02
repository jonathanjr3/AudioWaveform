import SwiftUI
import Charts

public enum WaveformChartType {
    case line
    case bar
    case area
    case capsule
}

public struct AudioWaveformView: View {
    @State private var monitor: AudioWaveformMonitor

    private let style: AnyShapeStyle
    private let chartType: WaveformChartType
    private let interpolationMethod: InterpolationMethod
    private let downsampleFactor: Int
    private let renderSize: CGSize?
    private let capsuleHeightScale: CGFloat = 0.75

    public init<S: ShapeStyle>(
        monitor: AudioWaveformMonitor = .shared,
        style: S = Color.blue,
        chartType: WaveformChartType = .line,
        interpolationMethod: InterpolationMethod = .catmullRom,
        downsampleFactor: Int = 8,
        renderSize: CGSize? = nil
    ) {
        self.monitor = monitor
        self.style = AnyShapeStyle(style)
        self.chartType = chartType
        self.interpolationMethod = interpolationMethod
        self.downsampleFactor = max(1, downsampleFactor)
        self.renderSize = renderSize
    }

    private var downsampledMagnitudes: [Float] {
        guard monitor.fftMagnitudes.isEmpty == false else { return [] }
        return stride(from: 0, to: monitor.fftMagnitudes.count, by: downsampleFactor).map {
            monitor.fftMagnitudes[$0]
        }
    }

    public var body: some View {
        Group {
            switch chartType {
            case .capsule:
                capsuleWaveform
            default:
                chartWaveform
            }
        }
        .animation(.easeOut, value: downsampledMagnitudes)
    }

    private var chartWaveform: some View {
        Chart(Array(downsampledMagnitudes.enumerated()), id: \.offset) { index, value in
            if chartType == .line {
                LineMark(
                    x: .value("Frequency", index * downsampleFactor),
                    y: .value("Magnitude", value)
                )
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(style)
            } else if chartType == .bar {
                BarMark(
                    x: .value("Frequency", index * downsampleFactor),
                    y: .value("Magnitude", value),
                    width: .fixed(CGFloat(max(1, downsampleFactor)))
                )
                .foregroundStyle(style)
            } else {
                AreaMark(
                    x: .value("Frequency", index * downsampleFactor),
                    y: .value("Magnitude", value)
                )
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(style)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(monitor.fftMagnitudes.max() ?? 0, 100))
    }

    private var capsuleWaveform: some View {
        GeometryReader { geometry in
            let size = renderSize ?? geometry.size
            let values = downsampledMagnitudes
            let maxValue = max(values.max() ?? 1, 1)
            let count = max(values.count, 1)
            let step = size.width / CGFloat(count)
            let minWidth = size.width * 0.01
            let candidateWidth = step * 0.55
            let barWidth = min(max(candidateWidth, minWidth), step)
            let spacing = max(step - barWidth, 0)
            let minHeight = max(barWidth, size.height * 0.05)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    let normalized = CGFloat(value) / CGFloat(maxValue)
                    let dampened = normalized * capsuleHeightScale
                    let height = max(minHeight, dampened * size.height)
                    Capsule()
                        .fill(style)
                        .frame(width: barWidth, height: height)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .center)
        }
        .frame(width: renderSize?.width, height: renderSize?.height)
    }
}
