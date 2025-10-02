# AudioWaveform

AudioWaveform is a Swift package that turns microphone samples into a live waveform you can drop into any SwiftUI app. You keep full control of the audio capture pipeline—pipe your buffers into the package and it handles the  rendering.

This package is inspired by and based on the concepts presented in the article [Creating a Live Audio Waveform in SwiftUI](https://www.createwithswift.com/creating-a-live-audio-waveform-in-swiftui/).

## Features

- ⚡ **Real-Time FFT Processing** – Uses Accelerate to transform incoming audio into magnitude bins optimised for visualisation.
- 🎨 **Customisable SwiftUI View** – Render the waveform as a line, bar, area, or capsule chart and style it with colours or gradients.

## Requirements

- iOS 18.0+
- macOS 15.0+
- Xcode 16.0+
- Swift 6.0+

## Installation

1. In Xcode, choose **File > Add Package Dependencies…**
2. Enter the repository URL: `https://github.com/jonathanjr3/AudioWaveform.git`
3. Select the version rules that fit your project and add the package to your target.

## Getting Started

The package exposes two primary types:

- `AudioWaveformMonitor`: receives audio samples and publishes FFT magnitudes that your UI can observe.
- `AudioWaveformView`: a SwiftUI view that visualises those magnitudes in waveforms

### 1. Request Microphone Permission

Add the following key to your app’s `Info.plist`:

- **Privacy – Microphone Usage Description**: explain why you need microphone access.

### 2. Capture Audio Buffers

Install a tap on your existing `AVAudioEngine` (or other capture source) and forward every buffer to the monitor. The same tap can simultaneously feed frameworks such as Speech or SoundAnalysis.

```swift
import AVFoundation
import AudioWaveform

final class AudioCaptureController {
    let monitor = AudioWaveformMonitor.shared
    private let engine = AVAudioEngine()

    func start() throws {
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 8192, format: format) { buffer, _ in
            monitor.process(buffer: buffer)
            // Append the same buffer to your speech recognizer here, if using any.
        }

        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        monitor.reset()
    }
}
```

**Note:** Set `AudioWaveformMonitor`'s `fftSize` to the same value you pass as the tap's `bufferSize`. Matching the sizes avoids extra zero-padding work and ensures the FFT represents the exact frames you captured.

If you are working with raw sample arrays (for example, from a network stream), call `monitor.process(samples:)` instead.

### 3. Display the Waveform in SwiftUI

Inject the monitor into `AudioWaveformView` and embed it in your layout.

```swift
import SwiftUI
import AudioWaveform

struct ContentView: View {
    @State private var monitor = AudioWaveformMonitor.shared

    var body: some View {
        VStack(spacing: 32) {
            Text("Live Audio Waveform")
                .font(.title.bold())

            AudioWaveformView(
                monitor: monitor,
                style: Color.cyan,
                chartType: .area,
                interpolationMethod: .catmullRom
            )
            .frame(height: 240)
        }
        .padding()
    }
}
```

## Customisation

Configure the view at creation time:

```swift
AudioWaveformView(
    monitor: AudioWaveformMonitor(fftSize: 4096, magnitudeCount: 128),
    style: LinearGradient(colors: [.green, .blue], startPoint: .bottom, endPoint: .top),
    chartType: .capsule,
    interpolationMethod: .monotone,
    downsampleFactor: 8,
    renderSize: CGSize(width: 240, height: 96)
)
```

- `fftSize` / `magnitudeCount`: control FFT resolution if you initialise a custom monitor.
- `style`: accepts any `ShapeStyle` (`Color`, `LinearGradient`, `AngularGradient`, etc.).
- `chartType`: `.line`, `.bar`, `.area`, or `.capsule` for a rounded bar style similar to digital waveforms.
- `renderSize`: optionally pin the capsule waveform to a fixed size so spacing and bar width match your design.
- `interpolationMethod`: forwarded to Swift Charts for smooth curves.
- `downsampleFactor`: skip bins to simplify the waveform.

Call `monitor.reset()` when you end a recording to clear the visualization. When using `.capsule`, provide a `renderSize` and an apt `downsampleFactor` to fit within the given width.

## Advanced Notes

- The processor clamps magnitudes to `0...100` by default, adjust UI scaling via `downsampleFactor` or Swift Charts modifiers.
