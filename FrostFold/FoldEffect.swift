//
//  FoldEffect.swift
//  FrostFold
//

import SwiftUI

struct FoldParameters: Equatable {
    var eyeDistanceMillimeters: CGFloat = 320
    var pointsPerMillimeter: CGFloat = 6
    var blurSpread: CGFloat = 0.12
    var darkening: CGFloat = 0.015
    /// Separation the glass keeps from the UI plane even at the hinge, so no part of a tilted
    /// screen stays perfectly clear and the hinge edge does not read as a hard boundary.
    var baseSeparationPoints: CGFloat = 10

    var eyeDistancePoints: CGFloat { eyeDistanceMillimeters * pointsPerMillimeter }
}

extension View {
    /// Renders the view as if seen through a frosted-glass pane tilted by `angle` (radians)
    /// around the screen-space Y axis, hinged on the edge farther from the viewer.
    func foldEffect(angle: Double, parameters: FoldParameters = FoldParameters()) -> some View {
        modifier(FoldEffectModifier(angle: angle, parameters: parameters))
    }
}

private struct FoldEffectModifier: ViewModifier {
    let angle: Double
    let parameters: FoldParameters

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .visualEffect { [angle, parameters] content, _ in
                content.layerEffect(
                    ShaderLibrary.frostFold(
                        .boundingRect,
                        .float(angle),
                        .float(parameters.eyeDistancePoints),
                        .float(parameters.blurSpread),
                        .float(parameters.darkening),
                        .float(parameters.baseSeparationPoints)
                    ),
                    maxSampleOffset: .zero,
                    isEnabled: abs(angle) > 1e-4
                )
            }
    }
}
