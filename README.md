# AudioWaveform

A modern and customizable Swift package for rendering live audio waveforms in SwiftUI. Built with the latest APIs, including `SwiftUI`, `Charts`, and `Observation`, this package provides a simple way to visualize audio input from the microphone.

This package is inspired by and based on the concepts presented in the article [Creating a Live Audio Waveform in SwiftUI](https://www.createwithswift.com/creating-a-live-audio-waveform-in-swiftui/).

## Features

-   🎤 **Live Audio Visualization**: Captures audio from the device's microphone and displays it as a real-time waveform.
-   🎨 **Highly Customizable**: Easily change the waveform's color, chart type (line, bar, or area), and interpolation method.

## Requirements

-   iOS 18.0+
-   macOS 15.0+
-   Xcode 16.0+
-   Swift 6.0+

## Installation

You can add `AudioWaveform` to your Xcode project as a package dependency.

1.  In Xcode, open your project and navigate to **File > Add Package Dependencies...**
2.  Enter the repository URL: `https://github.com/jonathanjr3/AudioWaveform.git`
3.  Choose the version rules and add the package to your desired target.

## How to Use

The package is designed to be incredibly simple to use. It consists of a data model, `AudioWaveformMonitor`, and a SwiftUI view, `AudioWaveformView`.

### 1. Request Microphone Permission

First, ensure your app has permission to access the microphone. Add the following key to your app's `Info.plist` file:

-   **Privacy - Microphone Usage Description**: `(Your reason for needing the microphone, e.g., "To visualize audio input.")`

### 2. Display the Waveform

Import the package and use the `AudioWaveformView` in your SwiftUI view. You can control the monitoring process using the `AudioWaveformMonitor.shared` singleton.

Here is a complete example:

```swift
import SwiftUI
import SwiftUIAudioWaveform

struct ContentView: View {
    // Access the shared monitor instance
    @State private var monitor = AudioWaveformMonitor.shared

    var body: some View {
        VStack(spacing: 30) {
            Text("Live Audio Waveform")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Add the waveform view
            AudioWaveformView(
                color: .cyan,
                chartType: .area,
                interpolationMethod: .catmullRom
            )
            .frame(height: 250)

            Button(action: {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    Task {
                        // Start monitoring in a background task
                        await monitor.startMonitoring()
                    }
                }
            }) {
                Label(monitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring",
                      systemImage: monitor.isMonitoring ? "mic.slash.fill" : "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(monitor.isMonitoring ? .red : .accentColor)
        }
        .padding()
    }
}
```

## Customization

You can customize the appearance of the `AudioWaveformView` by passing parameters to its initializer.

```swift
public init(
    color: Color = .blue,
    chartType: WaveformChartType = .line,
    interpolationMethod: InterpolationMethod = .catmullRom,
    downsampleFactor: Int = 8
)
```

-   **`color`**: The primary color of the waveform.
-   **`chartType`**: The type of chart to display. Can be `.line`, `.bar`, or `.area`.
-   **`interpolationMethod`**: The `InterpolationMethod` for `LineMark` and `AreaMark` from the `Swift Charts` framework.
-   **`downsampleFactor`**: An integer factor to downsample the FFT data, which can simplify the visual complexity of the waveform.

### Example with Customizations

Here's how you could create a segmented control to switch between different chart types dynamically.

```swift
import SwiftUI
import SwiftUIAudioWaveform

struct ContentView: View {
    @State private var monitor = AudioWaveformMonitor.shared
    @State private var chartType: WaveformChartType = .line

    var body: some View {
        VStack(spacing: 20) {
            Picker("Chart Type", selection: $chartType) {
                Text("Line").tag(WaveformChartType.line)
                Text("Bar").tag(WaveformChartType.bar)
                Text("Area").tag(WaveformChartType.area)
            }
            .pickerStyle(.segmented)
            
            AudioWaveformView(chartType: chartType)
                .frame(height: 300)

            // ... Start/Stop Button
        }
        .padding()
    }
}
```