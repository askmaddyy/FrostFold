# FrostFold

Your phone is a slab of frosted glass. The interface is not on it, it is behind it, floating on a
fixed plane in the room. Tilt the phone and the interface stays exactly where it was in space, while
the screen shows you what you would see through a pane of cloudy glass that has swung away from it.

<video src="https://github.com/askmaddyy/FrostFold/raw/main/Docs/demo.mp4" controls muted loop playsinline width="320"></video>

[Download the clip](Docs/demo.mp4) if the player does not load.

## The model

- The interface lives on a fixed plane in the world: the plane the screen occupied at zero tilt.
- The viewer does not move. Their eye stays on that plane's normal through the screen center, at a
  hand-held distance of about 320 mm.
- When the device tilts, the screen rotates around the edge that is farther from the viewer. That
  edge stays in the interface plane; the rest of the glass rises toward the eye.
- For every pixel, a Metal `layerEffect` casts a ray from the eye through that pixel's position on
  the rotated glass and continues it to the interface plane. It samples the interface there with a
  disk blur whose radius grows with the gap between glass and plane, dims the result by the same
  measure, and paints black wherever a ray misses the interface entirely.

Nothing is animated. The frame you see is a function of where the phone is pointing right now.

## Layout

| File | Role |
| --- | --- |
| `FrostFold/Shaders/FrostFold.metal` | The `layerEffect` shader: reprojection, blur, darkening. |
| `FrostFold/FoldEffect.swift` | `.foldEffect(angle:parameters:)` and the tunables in `FoldParameters`. |
| `FrostFold/FoldMotionModel.swift` | Core Motion: calibrated zero pose, tilt around the screen's Y axis, gyro prediction. |
| `FrostFold/DemoContentView.swift` | The interface being looked at. |
| `FrostFold/ContentView.swift` | Composition plus a floating panel for recalibration and manual tilt. |

## Tunables

`FoldParameters` holds the physics:

| Parameter | Default | Meaning |
| --- | --- | --- |
| `eyeDistanceMillimeters` | 320 | How far your eye sits from the interface plane. |
| `blurSpread` | 0.12 | Blur radius gained per point of glass-to-plane separation. |
| `darkening` | 0.015 | Light lost per point of blur radius. |
| `baseSeparationPoints` | 10 | Separation the glass keeps even at the hinge, so the hinge edge never reads as a hard line. |

## Running it

Open `FrostFold.xcodeproj` and run on a device. The first motion sample becomes the zero-tilt pose;
the panel in the bottom-right corner recalibrates or switches to a manual tilt slider.

The simulator has no motion data, so manual mode is on by default. A launch-time tilt can be passed
for screenshots:

```sh
SIMCTL_CHILD_TILT_DEGREES=-14 xcrun simctl launch booted com.askmaddyy.FrostFold
```

## Notes

- Everything under the effect must be pure SwiftUI. UIKit-backed views such as `ScrollView` are not
  rasterized into a shader layer, and the subtree has to be flattened with a compositing group first,
  otherwise SwiftUI shades every leaf view on its own transparent layer.
- The Core Motion rotation matrix convention is resolved at runtime against the gravity vector, so
  the hinge lands on the correct side without depending on documentation.

## License

MIT, see [LICENSE](LICENSE).
