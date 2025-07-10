import Testing

@testable import AudioWaveformMonitor

@Test("Monitor Initial State")
func monitorInitialState() {
    let monitor = AudioWaveformMonitor.shared

    #expect(monitor.isMonitoring == false, "Monitor should not be active initially.")
    #expect(
        monitor.fftMagnitudes.count == 200,
        "Initial FFT magnitudes array should have a count of 200.")
    #expect(
        monitor.fftMagnitudes.allSatisfy { $0 == 0 }, "All initial FFT magnitudes should be zero.")
}

@Test("Monitor Start and Stop Monitoring")
func monitorStartAndStop() async {
    let monitor = AudioWaveformMonitor.shared

    // This test checks the state of `isMonitoring` but cannot verify audio processing in a test environment.
    await monitor.startMonitoring()
    #expect(monitor.isMonitoring == true, "Monitor should be active after starting.")

    monitor.stopMonitoring()
    #expect(monitor.isMonitoring == false, "Monitor should be inactive after stopping.")
    #expect(
        monitor.fftMagnitudes.allSatisfy { $0 == 0 },
        "FFT magnitudes should be reset to zero after stopping.")
}

@Test("FFT Data Processing")
func fftDataProcessing() async {
    let monitor = AudioWaveformMonitor.shared

    // Create a sample sine wave to test the FFT
    let sampleCount = 8192
    let frequency: Float = 440.0
    let sampleRate: Float = 44100.0
    let sineWave = (0..<sampleCount).map {
        sin(2.0 * .pi * frequency * Float($0) / sampleRate)
    }

    let magnitudes = await monitor.performFFT(data: sineWave)

    #expect(magnitudes.count == 200, "The number of magnitude values should be 200.")
    #expect(magnitudes.allSatisfy { $0 >= 0 }, "Magnitudes cannot be negative.")

    // Find the peak magnitude, which should correspond to our input frequency
    if let maxMagnitude = magnitudes.max(), maxMagnitude > 0 {
        // Test passed: The FFT produced a non-zero output
    } else {
        Issue.record("The FFT did not produce a valid peak for a known sine wave input.")
    }
}

@Test("View Initialization and Properties")
func viewInitialization() {
    let color = Color.green
    let chartType = WaveformChartType.bar

    let view = AudioWaveformView(color: color, chartType: chartType)

    // Directly testing SwiftUI properties is complex, but we can check the configuration.
    #expect(view.color == color, "The view's color should be configurable.")
    #expect(view.chartType == chartType, "The view's chart type should be configurable.")
}
