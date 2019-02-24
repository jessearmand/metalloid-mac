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
    let scene: Scene

    var meshes: [MTKMesh] = []
    var time: Float = 0

    let commandQueue: MTLCommandQueue?
    var baseColorTexture: MTLTexture?

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
        scene = Renderer.buildScene(device: mtlDevice, vertexDescriptor: vertexDescriptor)

        super.init()
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

    static func buildScene(device: MTLDevice, vertexDescriptor: MDLVertexDescriptor) -> Scene {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]

        let scene = Scene()

        let node = Node(name: "formica_rufa")
        let modelURL = Bundle.main.url(forResource: "formica_rufa", withExtension: "obj")
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        let light0 = Light(worldPosition: float3( 2,  2, 2), color: float3(1, 0, 0))
        let light1 = Light(worldPosition: float3(-2,  2, 2), color: float3(0, 1, 0))
        let light2 = Light(worldPosition: float3( 0, -2, 2), color: float3(0, 0, 1))
        scene.lights = [light0, light1, light2]

        do {
            node.mesh = try MTKMesh.newMeshes(asset: asset, device: device).metalKitMeshes.first
            node.material.baseColorTexture = try textureLoader.newTexture(name: "texture", scaleFactor: 1.0, bundle: nil, options: options)
            node.material.specularPower = 200
            node.material.specularColor = float3(0.8, 0.8, 0.8)
            scene.rootNode.children.append(node)
        } catch let error {
            fatalError("\(error)")
        }

        return scene
    }

    static func buildPipeline(device: MTLDevice, view: MTKView, vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary() else {
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

        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
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
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        time += 1 / Float(view.preferredFramesPerSecond)
        scene.update(time: time, aspectRatio: aspectRatio)

        let commandBuffer = commandQueue?.makeCommandBuffer()

        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            guard let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                fatalError("No command encoder for rendering")
            }

            commandEncoder.setDepthStencilState(depthStencilState)
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)
            commandEncoder.setRenderPipelineState(renderPipeline)

            scene.drawRecursive(
                node: scene.rootNode,
                parentTransform: matrix_identity_float4x4,
                commandEncoder: commandEncoder
            )

            commandEncoder.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
