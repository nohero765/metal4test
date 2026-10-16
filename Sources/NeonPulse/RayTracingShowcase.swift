import Metal
import simd

final class RayTracingShowcase {
    let accelerationStructure: MTLAccelerationStructure
    let pipeline: MTLComputePipelineState

    init?(device: MTLDevice, library: MTLLibrary) {
        guard device.supportsRaytracing,
              let queue = device.makeCommandQueue(),
              let commandBuffer = queue.makeCommandBuffer(),
              let function = library.makeFunction(name: "neon_path_trace") else {
            return nil
        }

        let vertices: [SIMD3<Float>] = [
            SIMD3<Float>(-1, -1, 0),
            SIMD3<Float>(1, -1, 0),
            SIMD3<Float>(0, 1, 0)
        ]
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<SIMD3<Float>>.stride * vertices.count, options: .storageModeShared) else {
            return nil
        }

        let geometry = MTLAccelerationStructureTriangleGeometryDescriptor()
        geometry.vertexBuffer = vertexBuffer
        geometry.vertexStride = MemoryLayout<SIMD3<Float>>.stride
        geometry.triangleCount = 1

        let bottomLevel = MTLPrimitiveAccelerationStructureDescriptor()
        bottomLevel.geometryDescriptors = [geometry]
        let bottomSizes = device.accelerationStructureSizes(descriptor: bottomLevel)
        guard bottomSizes.accelerationStructureSize > 0,
              let bottom = device.makeAccelerationStructure(size: bottomSizes.accelerationStructureSize),
              let scratch = device.makeBuffer(length: bottomSizes.buildScratchBufferSize, options: .storageModePrivate),
              let encoder = commandBuffer.makeAccelerationStructureCommandEncoder() else {
            return nil
        }
        encoder.build(accelerationStructure: bottom, descriptor: bottomLevel, scratchBuffer: scratch, scratchBufferOffset: 0)

        let instance = MTLAccelerationStructureInstanceDescriptor(
            transformationMatrix: MTLPackedFloat4x3(columns: (
                MTLPackedFloat3Make(1, 0, 0),
                MTLPackedFloat3Make(0, 1, 0),
                MTLPackedFloat3Make(0, 0, 1),
                MTLPackedFloat3Make(0, 0, 0)
            )),
            options: [],
            mask: 0xFF,
            intersectionFunctionTableOffset: 0,
            accelerationStructureIndex: 0
        )
        guard let instanceBuffer = device.makeBuffer(bytes: [instance], length: MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride, options: .storageModeShared) else {
            encoder.endEncoding()
            return nil
        }

        let topLevel = MTLInstanceAccelerationStructureDescriptor()
        topLevel.instancedAccelerationStructures = [bottom]
        topLevel.instanceCount = 1
        topLevel.instanceDescriptorBuffer = instanceBuffer
        let topSizes = device.accelerationStructureSizes(descriptor: topLevel)
        guard topSizes.accelerationStructureSize > 0,
              let top = device.makeAccelerationStructure(size: topSizes.accelerationStructureSize),
              let topScratch = device.makeBuffer(length: topSizes.buildScratchBufferSize, options: .storageModePrivate) else {
            encoder.endEncoding()
            return nil
        }
        encoder.build(accelerationStructure: top, descriptor: topLevel, scratchBuffer: topScratch, scratchBufferOffset: 0)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard commandBuffer.status == .completed,
              let pipeline = try? device.makeComputePipelineState(function: function) else {
            return nil
        }
        accelerationStructure = top
        self.pipeline = pipeline
    }
}
