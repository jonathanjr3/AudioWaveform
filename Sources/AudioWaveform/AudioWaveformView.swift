import SwiftUI
import Charts

public enum WaveformChartType {
    case line
    case bar
    case area
}

public struct AudioWaveformView: View {
    @State private var monitor = AudioWaveformMonitor.shared

    private var color: Color
    private var chartType: WaveformChartType
    private var interpolationMethod: InterpolationMethod
    private var downsampleFactor: Int

    public init(
        color: Color = .blue,
        chartType: WaveformChartType = .line,
        interpolationMethod: InterpolationMethod = .catmullRom,
        downsampleFactor: Int = 8
    ) {
        self.color = color
        self.chartType = chartType
        self.interpolationMethod = interpolationMethod
        self.downsampleFactor = downsampleFactor
    }

    private var downsampledMagnitudes: [Float] {
        monitor.fftMagnitudes.lazy.enumerated().compactMap { index, value in
            index.isMultiple(of: downsampleFactor) ? value : nil
        }
    }

    public var body: some View {
        Chart(Array(downsampledMagnitudes.enumerated()), id: \.offset) { index, value in
            switch chartType {
            case .line:
                LineMark(
                    x: .value("Frequency", index * downsampleFactor),
                    y: .value("Magnitude", value)
                )
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(color)

            case .bar:
                BarMark(
                    x: .value("Frequency", index * downsampleFactor),
                    y: .value("Magnitude", value)
                )
                .foregroundStyle(color)

            case .area:
                AreaMark(
                    x: .value("Frequency", index * downsampleFactor),
                    y: .value("Magnitude", value)
                )
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(color.gradient)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(monitor.fftMagnitudes.max() ?? 0, 100))
        .animation(.easeOut, value: downsampledMagnitudes)
    }
}