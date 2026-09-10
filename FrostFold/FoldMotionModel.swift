//
//  FoldMotionModel.swift
//  FrostFold
//

import CoreMotion
import Observation
import UIKit
import simd

/// Derives the device's tilt around the screen-space Y axis from Core Motion attitude,
/// relative to a calibrated "zero tilt" pose.
@Observable @MainActor
final class FoldMotionModel {
    /// Tilt fed to the shader, in radians. Positive means the right edge is farther from the viewer.
    var tiltAngle: Double {
        usesManualTilt ? manualDegrees * .pi / 180 : motionTilt
    }

    var usesManualTilt: Bool
    var manualDegrees: Double
    private(set) var isMotionAvailable: Bool

    private(set) var motionTilt: Double = 0

    @ObservationIgnored private let motionManager = CMMotionManager()
    @ObservationIgnored private var reference: simd_double3x3?
    /// Whether `CMRotationMatrix` rows hold the device axes expressed in the reference frame.
    /// Resolved empirically against the gravity vector on the first informative sample.
    @ObservationIgnored private var rowsAreDeviceAxes: Bool?
    /// Fraction of the remaining error closed per sample. Kept high: the attitude is already fused,
    /// and every extra frame of filtering is visible as lag between the hand and the screen.
    @ObservationIgnored private let smoothing = 0.7
    /// How far ahead to extrapolate with the gyroscope, to cover sensor and display latency.
    @ObservationIgnored private let predictionInterval = 0.04

    init() {
        // Launch-time override for simulator runs: `-tiltDegrees 20` or TILT_DEGREES=-20.
        let defaults = UserDefaults.standard
        let environment = ProcessInfo.processInfo.environment
        manualDegrees = environment["TILT_DEGREES"].flatMap(Double.init) ?? defaults.double(forKey: "tiltDegrees")
        isMotionAvailable = motionManager.isDeviceMotionAvailable
        #if targetEnvironment(simulator)
        usesManualTilt = true
        #else
        usesManualTilt = defaults.bool(forKey: "manualTilt") || !motionManager.isDeviceMotionAvailable
        #endif
    }

    func start() {
        guard isMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        // Gyro-only reference frame: the magnetometer-corrected variants trade latency for
        // long-term yaw stability, and yaw is exactly the axis this effect tracks.
        motionManager.deviceMotionUpdateInterval = 1.0 / 120.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated { self?.process(motion) }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// Makes the current pose the zero-tilt pose: the plane the UI stays in.
    func recalibrate() {
        reference = nil
        motionTilt = 0
    }

    private func process(_ motion: CMDeviceMotion) {
        let deviceToReference = deviceToReferenceMatrix(motion)
        guard let reference else {
            reference = deviceToReference
            return
        }

        // Current device axes expressed in the calibrated device frame.
        let relative = reference.transpose * deviceToReference
        let normal = relative.columns.2                     // current screen normal
        let (screenX, screenY) = screenAxesInDeviceSpace()
        let measured = atan2(simd_dot(normal, screenX), normal.z)

        // Extrapolate along the rotation rate around the screen's Y axis.
        let rate = SIMD3(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
        let predicted = measured + simd_dot(rate, screenY) * predictionInterval

        motionTilt += (predicted - motionTilt) * smoothing
    }

    /// Rotation taking device-frame vectors to reference-frame vectors (column-vector convention).
    private func deviceToReferenceMatrix(_ motion: CMDeviceMotion) -> simd_double3x3 {
        let m = motion.attitude.rotationMatrix
        let asRows = simd_double3x3(rows: [
            SIMD3(m.m11, m.m12, m.m13),
            SIMD3(m.m21, m.m22, m.m23),
            SIMD3(m.m31, m.m32, m.m33),
        ])

        if rowsAreDeviceAxes == nil {
            // Gravity is reported in the device frame and points down (-Z in a Z-vertical reference).
            // Compare it against what each matrix convention predicts and latch the better match.
            let gravity = simd_normalize(SIMD3(motion.gravity.x, motion.gravity.y, motion.gravity.z))
            let down = SIMD3(0.0, 0.0, -1.0)
            let rowsScore = simd_dot(gravity, asRows * down)
            let columnsScore = simd_dot(gravity, asRows.transpose * down)
            if abs(rowsScore - columnsScore) > 0.2 {
                rowsAreDeviceAxes = rowsScore > columnsScore
            }
        }
        return (rowsAreDeviceAxes ?? true) ? asRows.transpose : asRows
    }

    /// Screen-space X (right) and Y (up) axes of the interface, in device coordinates.
    private func screenAxesInDeviceSpace() -> (x: SIMD3<Double>, y: SIMD3<Double>) {
        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .portrait
        switch orientation {
        case .landscapeLeft:        return (SIMD3(0, 1, 0), SIMD3(-1, 0, 0))
        case .landscapeRight:       return (SIMD3(0, -1, 0), SIMD3(1, 0, 0))
        case .portraitUpsideDown:   return (SIMD3(-1, 0, 0), SIMD3(0, -1, 0))
        default:                    return (SIMD3(1, 0, 0), SIMD3(0, 1, 0))
        }
    }
}
