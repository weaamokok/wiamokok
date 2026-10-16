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
    float2 ndcScale;   // 2/drawableW, 2/drawableH — reserved for future anisotropic brushes
};

// ─────────────────────────────────────────────────────────────────────────────
// Pipeline 1 — Blit canvas texture to screen as a fullscreen quad
// Buffer layout: buffer(0) = array of float4 (x,y,u,v) x 4 vertices (triangle strip)
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
    BlitVOut              in  [[stage_in]],
    texture2d<float>      tex [[texture(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    return tex.sample(s, in.uv);
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

fragment float4 stampFragmentShader(
    StampVOut               in [[stage_in]],
    constant BrushUniforms& u  [[buffer(0)]]
) {
    float dist = length(in.stampUV);

    // Smooth disc: full alpha inside 0.7, fades to 0 at radius 1.0
    float alpha = smoothstep(1.0, 0.7, dist) * u.opacity;
    if (alpha < 0.005) discard_fragment();

    return float4(u.color.rgb * alpha, alpha);   // pre-multiplied alpha
}
