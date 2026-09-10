//
//  ContentView.swift
//  FrostFold
//
//

import SwiftUI

struct ContentView: View {
    @State private var motion = FoldMotionModel()
    @State private var showsControls = false

    var body: some View {
        DemoContentView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .foldEffect(angle: motion.tiltAngle)
        .overlay(alignment: .bottomTrailing) { controls }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if showsControls {
                controlPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Button {
                withAnimation(.snappy) { showsControls.toggle() }
            } label: {
                Image(systemName: showsControls ? "xmark" : "slider.horizontal.3")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: .circle)
        }
        .padding()
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(motion.tiltAngle * 180 / .pi, format: .number.precision(.fractionLength(1)))
                    .monospacedDigit()
                Text("°")
                Spacer()
                Button("Recalibrate", systemImage: "scope") { motion.recalibrate() }
                    .disabled(motion.usesManualTilt || !motion.isMotionAvailable)
            }
            .font(.subheadline.weight(.medium))

            Toggle("Manual tilt", isOn: $motion.usesManualTilt)
                .disabled(!motion.isMotionAvailable)

            Slider(value: $motion.manualDegrees, in: -45...45, step: 0.5) {
                Text("Tilt")
            } minimumValueLabel: {
                Text("-45°").font(.caption2)
            } maximumValueLabel: {
                Text("45°").font(.caption2)
            }
            .disabled(!motion.usesManualTilt)
        }
        .padding(16)
        .frame(width: 280)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }
}

#Preview {
    ContentView()
}
