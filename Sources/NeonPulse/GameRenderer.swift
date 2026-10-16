import Foundation
import Metal
import MetalKit
import MetalFX
import simd

final class GameRenderer: NSObject, MTKViewDelegate {
    private struct Vertex {
        var position: SIMD2<Float>
        var color: SIMD4<Float>
    }

    private struct FrameUniforms {
        var viewport: SIMD2<Float>
        var cameraX: Float
        var time: Float
        var pulse: Float
    }

    private struct RayUniforms {
        var size: SIMD2<Float>
        var time: Float
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let uniformBuffer: MTLBuffer
    private let vertexBuffer: MTLBuffer
    private var rayTracingShowcase: RayTracingShowcase?
    private let level = NeonPulseLevel()
    private var simulation = GameSimulation()
    private var time: Float = 0
    private var supportsMetalFX = false
    private var supportsRayTracing = false

    init(device: MTLDevice) {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Unable to create Metal command queue")
        }
        self.commandQueue = commandQueue

        let library = GameRenderer.makeLibrary(device: device)
        guard let vertexFunction = library.makeFunction(name: "neon_vertex"),
              let fragmentFunction = library.makeFunction(name: "neon_fragment") else {
            fatalError("Unable to load Neon Pulse shaders")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            fatalError("Unable to create render pipeline")
        }
        self.pipeline = pipeline

        guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<FrameUniforms>.stride, options: .storageModeShared),
              let vertexBuffer = device.makeBuffer(length: MemoryLayout<Vertex>.stride * 4096, options: .storageModeShared) else {
            fatalError("Unable to allocate renderer buffers")
        }
        self.uniformBuffer = uniformBuffer
        self.vertexBuffer = vertexBuffer
        supportsMetalFX = MTLFXSpatialScalerDescriptor.supportsDevice(device)
        rayTracingShowcase = RayTracingShowcase(device: device, library: library)
        supportsRayTracing = rayTracingShowcase != nil
        super.init()
    }

    func handleJump() {
        if simulation.player.completed || !simulation.player.alive {
            simulation.reset()
        } else {
            simulation.jump()
        }
    }

    func handleRestart() {
        simulation.reset()
    }

    func update(deltaTime: Float) {
        time += deltaTime
        simulation.update(deltaTime: deltaTime)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let width = drawable.texture.width
        let height = drawable.texture.height
        let viewport = SIMD2<Float>(Float(width), Float(height))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: drawable.texture.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        guard let renderTarget = device.makeTexture(descriptor: descriptor) else { return }

        if let rayTracingShowcase, let compute = commandBuffer.makeComputeCommandEncoder() {
            var rayUniforms = RayUniforms(size: viewport, time: time)
            if let buffer = device.makeBuffer(bytes: &rayUniforms, length: MemoryLayout<RayUniforms>.stride, options: .storageModeShared) {
                compute.setComputePipelineState(rayTracingShowcase.pipeline)
                compute.setAccelerationStructure(rayTracingShowcase.accelerationStructure, bufferIndex: 0)
                compute.setBuffer(buffer, offset: 0, index: 1)
                compute.setTexture(renderTarget, index: 0)
                compute.dispatchThreads(MTLSize(width: width, height: height, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
            }
            compute.endEncoding()
        }

        var uniforms = FrameUniforms(viewport: viewport, cameraX: simulation.player.position.x, time: time, pulse: simulation.player.jumpPulse)
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<FrameUniforms>.stride)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = renderTarget
        pass.colorAttachments[0].loadAction = rayTracingShowcase == nil ? .clear : .load
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        let count = buildVertices(viewport: viewport)
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: count)
        encoder.endEncoding()

        let blit = commandBuffer.makeBlitCommandEncoder()
        blit?.copy(from: renderTarget, to: drawable.texture)
        blit?.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func buildVertices(viewport: SIMD2<Float>) -> Int {
        let vertices = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: 4096)
        var index = 0
        let cameraX = simulation.player.position.x
        let viewWidth: Float = 28
        let left = cameraX - 4
        let right = left + viewWidth
        let ground = level.groundY

        func addQuad(_ rect: SIMD4<Float>, _ color: SIMD4<Float>) {
            let x = rect.x
            let y = rect.y
            let width = rect.z
            let height = rect.w
            let quad = [
                Vertex(position: SIMD2<Float>(x, y), color: color),
                Vertex(position: SIMD2<Float>(x + width, y), color: color),
                Vertex(position: SIMD2<Float>(x + width, y + height), color: color),
                Vertex(position: SIMD2<Float>(x, y), color: color),
                Vertex(position: SIMD2<Float>(x + width, y + height), color: color),
                Vertex(position: SIMD2<Float>(x, y + height), color: color)
            ]
            for vertex in quad {
                vertices[index] = vertex
                index += 1
            }
        }

        func addTriangle(_ x: Float, _ y: Float, _ size: Float, _ color: SIMD4<Float>) {
            let triangle = [
                Vertex(position: SIMD2<Float>(x, y), color: color),
                Vertex(position: SIMD2<Float>(x + size / 2, y + size), color: color),
                Vertex(position: SIMD2<Float>(x + size, y), color: color)
            ]
            for vertex in triangle {
                vertices[index] = vertex
                index += 1
            }
        }

        addQuad(SIMD4<Float>(left - 1, -1, viewWidth + 2, 1), SIMD4<Float>(0.025, 0.04, 0.10, 1))
        addQuad(SIMD4<Float>(left - 1, ground - 0.08, viewWidth + 2, 0.08), SIMD4<Float>(0.04, 0.95, 0.92, 1))
        addQuad(SIMD4<Float>(left - 1, ground - 0.2, viewWidth + 2, 0.12), SIMD4<Float>(0.03, 0.18, 0.24, 1))

        for line in stride(from: Int(floor(left)), through: Int(ceil(right)), by: 2) {
            let x = Float(line)
            addQuad(SIMD4<Float>(x, 0.5, 0.018, 8), SIMD4<Float>(0.03, 0.12, 0.22, 0.65))
        }
        for row in 0..<5 {
            addQuad(SIMD4<Float>(left, Float(row) * 1.5 + 0.5, viewWidth, 0.012), SIMD4<Float>(0.03, 0.12, 0.22, 0.65))
        }

        for obstacle in level.obstacles where obstacle.x + obstacle.width > left && obstacle.x < right {
            switch obstacle.kind {
            case .block:
                addQuad(SIMD4<Float>(obstacle.x, ground, obstacle.width, obstacle.height), SIMD4<Float>(0.16, 0.28, 0.96, 1))
                addQuad(SIMD4<Float>(obstacle.x + 0.08, ground + 0.08, obstacle.width - 0.16, obstacle.height - 0.16), SIMD4<Float>(0.06, 0.09, 0.23, 1))
            case .spike:
                addTriangle(obstacle.x, ground, 1, SIMD4<Float>(0.98, 0.18, 0.62, 1))
            case .pad:
                addQuad(SIMD4<Float>(obstacle.x, ground, obstacle.width, 0.15), SIMD4<Float>(0.98, 0.77, 0.12, 1))
            }
        }

        let player = simulation.player.position
        let playerColor = simulation.player.alive ? SIMD4<Float>(0.98, 0.91, 0.22, 1) : SIMD4<Float>(0.96, 0.18, 0.28, 1)
        addQuad(SIMD4<Float>(player.x - 0.4, player.y, 0.8, 0.8), playerColor)
        addQuad(SIMD4<Float>(player.x - 0.24, player.y + 0.16, 0.16, 0.16), SIMD4<Float>(0.04, 0.05, 0.15, 1))
        addQuad(SIMD4<Float>(player.x + 0.08, player.y + 0.16, 0.16, 0.16), SIMD4<Float>(0.04, 0.05, 0.15, 1))

        return index
    }

    private static func makeLibrary(device: MTLDevice) -> MTLLibrary {
        guard let url = Bundle.module.url(forResource: "NeonShaders", withExtension: "metal"),
              let source = try? String(contentsOf: url, encoding: .utf8),
              let library = try? device.makeLibrary(source: source, options: nil) else {
            fatalError("Unable to compile Neon Pulse shaders")
        }
        return library
    }
}
