//
//  Renderer.swift
//  Metaloid
//
//  Created by Jesse Armand on 16/2/19.
//  Copyright © 2019 Jesse Armand. All rights reserved.
//

import Foundation
import MetalKit
import ModelIO
import simd

struct VertexUniforms {
    var viewProjectionMatrix: float4x4
    var modelMatrix: float4x4
    var normalMatrix: float3x3
}

struct FragmentUniforms {
    var cameraWorldPosition = float3(0, 0, 0)
    var ambientLightColor = float3(0, 0, 0)
    var specularColor = float3(1, 1, 1)
    var specularPower = Float(1)
    var light0 = Light()
    var light1 = Light()
    var light2 = Light()
}

final class Renderer: NSObject {
    let view: MTKView
    let device: MTLDevice?
    let vertexDescriptor: MDLVertexDescriptor
    let renderPipeline: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState
    let samplerState: MTLSamplerState

    var meshes: [MTKMesh] = []
    var time: Float = 0

    let commandQueue: MTLCommandQueue?
    var baseColorTexture: MTLTexture?

    var viewMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4
    var cameraWorldPosition = float3(0, 0, 2)

    init(withView view: MTKView, device: MTLDevice?) {
        self.view = view
        self.device = device

        guard let mtlDevice = device else {
            fatalError("No metal device was created")
        }

        vertexDescriptor = Renderer.buildVertexDescriptor()
        renderPipeline = Renderer.buildPipeline(device: mtlDevice, view: view, vertexDescriptor: vertexDescriptor)
        depthStencilState = Renderer.buildDepthStencilState(device: mtlDevice)
        samplerState = Renderer.buildSamplerState(device: mtlDevice)
        commandQueue = mtlDevice.makeCommandQueue()

        super.init()
        loadResources()
    }

    static func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }

    static func buildVertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: MemoryLayout<Float>.size * 3,
                                                            bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                            format: .float2,
                                                            offset: MemoryLayout<Float>.size * 6,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
        return vertexDescriptor
    }

    static func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }

    func loadResources() {
        let modelURL = Bundle.main.url(forResource: "formica_rufa", withExtension: "obj")

        guard let mtlDevice = device else {
            fatalError("No metal device was created")
        }
        let bufferAllocator = MTKMeshBufferAllocator(device: mtlDevice)
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        do {
            (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: mtlDevice)
        } catch let error {
            fatalError("Could not extract meshes from Model I/O \(error)")
        }

        let textureLoader = MTKTextureLoader(device: mtlDevice)
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]
        baseColorTexture = try? textureLoader.newTexture(name: "texture", scaleFactor: 1.0, bundle: nil, options: options)
    }

    static func buildPipeline(device: MTLDevice?, view: MTKView, vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        guard let library = device?.makeDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }

        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)

        guard let mtlDevice = device else {
            fatalError("No metal device was created")
        }

        do {
            return try mtlDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state object: \(error)")
        }
    }
}

extension Renderer: MTKViewDelegate {
    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }

    func draw(in view: MTKView) {
        time += 1 / Float(view.preferredFramesPerSecond)
        let angle = -time
        let modelMatrix = float4x4(scaleBy: 1.0)

        cameraWorldPosition = float3(0, 0, 2)
        viewMatrix = float4x4(translationBy: -cameraWorldPosition) * float4x4(rotationAbout: float3(0, 1, 0), by: angle)

        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi/3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
        let viewProjectionMatrix =  projectionMatrix * viewMatrix
        var vertexUniforms = VertexUniforms(
            viewProjectionMatrix: viewProjectionMatrix,
            modelMatrix: modelMatrix,
            normalMatrix: modelMatrix.normalMatrix
        )

        let commandBuffer = commandQueue?.makeCommandBuffer()

        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            commandEncoder?.setDepthStencilState(depthStencilState)
            commandEncoder?.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)

            let material = Material()
            material.specularPower = 200
            material.specularColor = float3(0.8, 0.8, 0.8)

            let light0 = Light(worldPosition: float3( 2,  2, 2), color: float3(1, 0, 0))
            let light1 = Light(worldPosition: float3(-2,  2, 2), color: float3(0, 1, 0))
            let light2 = Light(worldPosition: float3( 0, -2, 2), color: float3(0, 0, 1))

            var fragmentUniforms = FragmentUniforms(cameraWorldPosition: cameraWorldPosition,
                                                    ambientLightColor: float3(0.1, 0.1, 0.1),
                                                    specularColor: material.specularColor,
                                                    specularPower: material.specularPower,
                                                    light0: light0,
                                                    light1: light1,
                                                    light2: light2)
            commandEncoder?.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)

            commandEncoder?.setFragmentTexture(baseColorTexture, index: 0)
            commandEncoder?.setFragmentSamplerState(samplerState, index: 0)

            commandEncoder?.setRenderPipelineState(renderPipeline)

            for mesh in meshes {
                guard let vertexBuffer = mesh.vertexBuffers.first else {
                    fatalError("mesh vertex buffers is empty")
                }

                commandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)

                for submesh in mesh.submeshes {
                    commandEncoder?.drawIndexedPrimitives(
                        type: submesh.primitiveType,
                        indexCount: submesh.indexCount,
                        indexType: submesh.indexType,
                        indexBuffer: submesh.indexBuffer.buffer,
                        indexBufferOffset: submesh.indexBuffer.offset
                    )
                }
            }

            commandEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
