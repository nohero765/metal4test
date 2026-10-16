#include <metal_stdlib>
using namespace metal;

struct NeonVertex {
    float2 position;
    float4 color;
};

struct NeonUniforms {
    float2 viewport;
    float cameraX;
    float time;
    float pulse;
};

struct NeonOutput {
    float4 position [[position]];
    float4 color;
};

vertex NeonOutput neon_vertex(const device NeonVertex *vertices [[buffer(0)]], constant NeonUniforms &uniforms [[buffer(1)]], uint id [[vertex_id]]) {
    NeonVertex input = vertices[id];
    float2 screen = float2((input.position.x - uniforms.cameraX + 4.0) / 28.0, (input.position.y + 1.0) / 10.0);
    NeonOutput output;
    output.position = float4(screen * 2.0 - 1.0, 0.0, 1.0);
    output.color = input.color;
    return output;
}

fragment float4 neon_fragment(NeonOutput input [[stage_in]]) {
    return input.color;
}

struct RayUniforms {
    float2 size;
    float time;
};

kernel void neon_path_trace(texture2d<float, access::write> output [[texture(0)]], acceleration_structure accelerationStructure [[buffer(0)]], constant RayUniforms &uniforms [[buffer(1)]], uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(uniforms.size.x) || position.y >= uint(uniforms.size.y)) {
        return;
    }
    float2 uv = (float2(position) + 0.5) / uniforms.size;
    ray ray;
    ray.origin = float3((uv.x - 0.5) * 4.0, (uv.y - 0.5) * 2.0, 2.0);
    ray.direction = float3(0.0, 0.0, -1.0);
    ray.min_distance = 0.001;
    ray.max_distance = 20.0;
    intersector<triangle_data> tracer;
    auto hit = tracer.intersect(ray, accelerationStructure, 0xFF);
    float3 color = mix(float3(0.01, 0.02, 0.08), float3(0.04, 0.16, 0.3), uv.y);
    if (hit.type == intersection_type::triangle) {
        color = float3(0.0, 0.95, 0.72) * (0.35 + 0.65 * max(dot(-ray.direction, float3(0, 0, 1)), 0.0));
    }
    output.write(float4(color, 1.0), position);
}
