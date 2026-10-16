#include <metal_stdlib>
using namespace metal;

// ─────────────────────────────────────────────────────────────────────────────
// Shared types
// ─────────────────────────────────────────────────────────────────────────────

struct BrushUniforms {
    float2 position;   // NDC centre of the stamp
    float  size;       // NDC half-size of the stamp quad (half-width in NDC space)
    float  opacity;
    float4 color;      // (r, g, b, opacity) pre-multiplied when drawing
    float2 ndcScale;   // 2/drawableW, 2/drawableH
    float  azimuth;    // pencil tip direction in radians
    float  altitude;   // pencil tilt from surface: π/2 = upright, 0 = flat
};

// ─────────────────────────────────────────────────────────────────────────────
// Pipeline 1 — Blit a texture to the current render target (fullscreen quad).
// buffer(0) = float4[4] vertices (x,y,u,v), buffer(1) = float opacity
// ─────────────────────────────────────────────────────────────────────────────

struct BlitVOut {
    float4 position [[position]];
    float2 uv;
};

vertex BlitVOut blitVertexShader(
    uint              vid  [[vertex_id]],
    constant float4*  quad [[buffer(0)]]
) {
    BlitVOut out;
    out.position = float4(quad[vid].xy, 0, 1);
    out.uv       = quad[vid].zw;
    return out;
}

fragment float4 blitFragmentShader(
    BlitVOut              in      [[stage_in]],
    texture2d<float>      tex     [[texture(0)]],
    constant float&       opacity [[buffer(1)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 c = tex.sample(s, in.uv);
    // Pre-multiply opacity into alpha so the caller can use src-alpha blending
    return float4(c.rgb * opacity, c.a * opacity);
}

// ─────────────────────────────────────────────────────────────────────────────
// Pipeline 2 — Round brush stamp
// No vertex buffer: quad built procedurally from vertex_id (0-3 triangle strip).
// Buffer(0) = BrushUniforms for this stamp.
// ─────────────────────────────────────────────────────────────────────────────

struct StampVOut {
    float4 position  [[position]];
    float2 stampUV;   // [-1,1] relative to stamp centre — used for disc SDF
};

vertex StampVOut stampVertexShader(
    uint                    vid [[vertex_id]],
    constant BrushUniforms& u   [[buffer(0)]]
) {
    // Corners of a screen-aligned quad in [-1,1] stamp space
    const float2 corners[4] = {
        float2(-1,  1),
        float2( 1,  1),
        float2(-1, -1),
        float2( 1, -1)
    };
    float2 c = corners[vid];

    StampVOut out;
    out.position = float4(u.position + c * u.size, 0, 1);
    out.stampUV  = c;
    return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pipeline 3 — Eraser stamp (same shape as brush, cuts alpha out of layer)
// Uses erase blend: src*(0,0) + dst*(1-srcAlpha,1-srcAlpha)
// ─────────────────────────────────────────────────────────────────────────────

fragment float4 eraseFragmentShader(
    StampVOut               in [[stage_in]],
    constant BrushUniforms& u  [[buffer(0)]]
) {
    float tiltFactor = 1.0 - (u.altitude / (M_PI_F / 2.0));
    float aspectRatio = 1.0 + tiltFactor * 5.0;
    float cosA = cos(-u.azimuth); float sinA = sin(-u.azimuth);
    float2 uv  = in.stampUV;
    float2 rot = float2(uv.x*cosA - uv.y*sinA, uv.x*sinA + uv.y*cosA);
    float2 squished = float2(rot.x, rot.y * aspectRatio);
    float dist = length(squished);
    float alpha = smoothstep(1.0, 0.7, dist) * u.opacity;
    if (alpha < 0.005) discard_fragment();
    return float4(0.0, 0.0, 0.0, alpha);
}

// ─────────────────────────────────────────────────────────────────────────────
// Pipeline 4 — Smudge stamp (samples pickup texture at stamp centre)
// texture(0) = snapshot of the layer taken at stroke-begin
// ─────────────────────────────────────────────────────────────────────────────

fragment float4 smudgeFragmentShader(
    StampVOut               in     [[stage_in]],
    constant BrushUniforms& u      [[buffer(0)]],
    texture2d<float>        pickup [[texture(0)]]
) {
    float tiltFactor = 1.0 - (u.altitude / (M_PI_F / 2.0));
    float aspectRatio = 1.0 + tiltFactor * 5.0;
    float cosA = cos(-u.azimuth); float sinA = sin(-u.azimuth);
    float2 uv  = in.stampUV;
    float2 rot = float2(uv.x*cosA - uv.y*sinA, uv.x*sinA + uv.y*cosA);
    float2 squished = float2(rot.x, rot.y * aspectRatio);
    float dist = length(squished);
    float alpha = smoothstep(1.0, 0.7, dist) * u.opacity;
    if (alpha < 0.005) discard_fragment();

    // Convert NDC stamp centre to texture UV and sample the pickup colour
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 centerUV = float2((u.position.x + 1.0) * 0.5, (1.0 - u.position.y) * 0.5);
    float4 pickColor = pickup.sample(s, centerUV);
    return float4(pickColor.rgb * alpha, alpha);
}

fragment float4 stampFragmentShader(
    StampVOut               in [[stage_in]],
    constant BrushUniforms& u  [[buffer(0)]]
) {
    // ── Tilt-based ellipse deformation ──────────────────────────────────────
    // altitude π/2 = upright pencil → circle (aspect 1)
    // altitude 0   = flat pencil   → wide ellipse (aspect up to 6)
    float tiltFactor = 1.0 - (u.altitude / (M_PI_F / 2.0));   // 0 (upright) → 1 (flat)
    float aspectRatio = 1.0 + tiltFactor * 5.0;                 // 1 → 6

    // Rotate stamp UV so azimuth aligns with X-axis, then squish Y
    float cosA = cos(-u.azimuth);
    float sinA = sin(-u.azimuth);
    float2 uv  = in.stampUV;
    float2 rot = float2(uv.x * cosA - uv.y * sinA,
                        uv.x * sinA + uv.y * cosA);
    // Compress perpendicular axis to create an ellipse elongated along azimuth
    float2 squished = float2(rot.x, rot.y * aspectRatio);
    float dist = length(squished);

    // Smooth disc edge: full inside 0.7, fades to 0 at 1.0
    float alpha = smoothstep(1.0, 0.7, dist) * u.opacity;
    if (alpha < 0.005) discard_fragment();

    return float4(u.color.rgb * alpha, alpha);   // pre-multiplied alpha
}
