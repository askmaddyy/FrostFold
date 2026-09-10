//
//  FrostFold.metal
//  FrostFold
//
//  Frosted-glass "fold" effect.
//
//  Model: the UI lives on a fixed plane in the world, the plane the screen occupied at zero tilt.
//  The viewer does not move either: their eye stays where it was when they looked at the untilted
//  device head-on, on that plane's normal through the screen center. Only the glass moves: when the
//  device tilts by `angle` around the screen-space Y axis, the screen rotates around the edge farther
//  from the viewer, which stays in the UI plane, and the rest of the glass rises toward the eye.
//  Everything is computed in the UI plane's frame. For each screen pixel we:
//    1. place the pixel in 3D on the rotated glass,
//    2. cast a ray from the eye through it and continue until it meets the UI plane,
//    3. blur the UI around the hit point with a radius proportional to the gap between the glass
//       and the plane at that pixel.
//  Rays that miss the UI plane's content are black. A clear window would show the interface exactly
//  where it was, so the reprojection only redistributes which pixels show which part of it.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

constant int   kBlurTaps    = 32;
constant float kGoldenAngle = 2.39996322972865332;   // radians, Vogel disk spacing
constant float kTwoPi       = 6.28318530717958648;

static float hash21(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

static half4 opaque(half4 premultiplied) {
    // The layer is premultiplied; dropping alpha composites it over black.
    return half4(premultiplied.rgb, 1.0h);
}

[[ stitchable ]] half4 frostFold(float2 position,
                               SwiftUI::Layer layer,
                               float4 bounds,
                               float angle,
                               float eyeDistance,
                               float blurSpread,
                               float darkening,
                               float baseSeparation)
{
    const float2 size = bounds.zw;
    const float2 p    = position - bounds.xy;
    const float  tilt = abs(angle);

    if (tilt < 1e-5) {
        return opaque(layer.sample(position));
    }

    const bool  hingeRight = angle > 0.0;
    const float hingeX     = hingeRight ? size.x : 0.0;
    const float side       = hingeRight ? -1.0 : 1.0;
    const float d          = abs(p.x - hingeX);

    const float3 glass = float3(hingeX + side * d * cos(tilt), p.y, d * sin(tilt));
    const float3 eye   = float3(size * 0.5, eyeDistance);

    const float depth = eye.z - glass.z;
    if (depth <= 1e-3) {
        return half4(0.0h, 0.0h, 0.0h, 1.0h);
    }
    const float  t   = eye.z / depth;
    const float2 hit = eye.xy + (glass.xy - eye.xy) * t;

    const float radius = blurSpread * (glass.z + baseSeparation);

    if (any(hit < -radius) || any(hit > size + radius)) {
        return half4(0.0h, 0.0h, 0.0h, 1.0h);
    }

    const half attenuation = half(max(1.0 - darkening * radius, 0.0));

    if (radius < 0.5) {
        return opaque(layer.sample(bounds.xy + hit) * attenuation);
    }

    const int   taps     = clamp(int(radius * 2.0), 6, kBlurTaps);
    const float rotation = hash21(position) * kTwoPi;
    half3 sum = half3(0.0h);
    for (int i = 0; i < taps; ++i) {
        const float r = radius * sqrt((float(i) + 0.5) / float(taps));
        const float a = float(i) * kGoldenAngle + rotation;
        const float2 offset = r * float2(cos(a), sin(a));
        sum += layer.sample(bounds.xy + hit + offset).rgb;
    }
    return half4(sum / half(taps) * attenuation, 1.0h);
}
