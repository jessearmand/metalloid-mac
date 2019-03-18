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
    var light0 = Light(worldPosition: float3(0), color: float3(0))
    var light1 = Light(worldPosition: float3(0), color: float3(0))
    var light2 = Light(worldPosition: float3(0), color: float3(0))
}

final class Renderer: NSObject {
    let device: MTLDevice
    let vertexDescriptor: MDLVertexDescriptor
    let renderPipeline: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState
    let samplerState: MTLSamplerState
    let scene: Scene

    var meshes: [MTKMesh] = []
    var time: Float = 0

    let commandQueue: MTLCommandQueue
    var baseColorTexture: MTLTexture?

    static var childNodeCount = 10

    var touchDown = false
    var touchDownPoint = CGPoint.zero

    init(withView view: MTKView) {
        guard let device = view.device else {
            fatalError("No device was created for the renderer view")
        }

        self.device = device

        guard let mtlCommandQueue = device.makeCommandQueue() else {
            fatalError("Failed to make command queue for device")
        }

        commandQueue = mtlCommandQueue
        vertexDescriptor = Renderer.buildVertexDescriptor()
        renderPipeline = Renderer.buildPipeline(device: device, view: view, vertexDescriptor: vertexDescriptor)
        samplerState = Renderer.buildSamplerState(device: device)
        depthStencilState = Renderer.buildDepthStencilState(device: device)
        scene = Renderer.buildScene(device: device, vertexDescriptor: vertexDescriptor)

        super.init()

        view.delegate = self
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

    static func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear

        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            fatalError("Failed to make sampler state for device")
        }
        return samplerState
    }

    static func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true

        guard let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor) else {
            fatalError("Failed to make depth stencil state for device")
        }
        return depthStencilState
    }

    static func buildScene(device: MTLDevice, vertexDescriptor: MDLVertexDescriptor) -> Scene {
        let bufferAllocator: MTKMeshBufferAllocator = MTKMeshBufferAllocator(device: device)
        let textureLoader = MTKTextureLoader(device: device)

        let scene = Scene()
        scene.ambientLightColor = float3(0.1, 0.1, 0.1)
        let light0 = Light(worldPosition: float3( 5,  5, 0), color: float3(0.3, 0.3, 0.3))
        let light1 = Light(worldPosition: float3(-5,  5, 0), color: float3(0.3, 0.3, 0.3))
        let light2 = Light(worldPosition: float3( 0, -5, 0), color: float3(0.3, 0.3, 0.3))
        scene.lights = [light0, light1, light2]

        let modelURL = Bundle.main.url(forResource: "formica_rufa", withExtension: "obj")

        do {
            let centralNode = try Node.createChildNode(
                withName: "formica_rufa",
                modelURL: modelURL,
                textureName: "AntTexture",
                specularPower: 100,
                specularColor: float3(0.8, 0.8, 0.8),
                device: device,
                vertexDescriptor: vertexDescriptor,
                bufferAllocator: bufferAllocator,
                textureLoader: textureLoader
            )

            scene.rootNode.children.append(centralNode)

            for index in 1...Renderer.childNodeCount {
                let childModelURL = Bundle.main.url(forResource: "formica_rufa", withExtension: "obj")
                if let node = try? Node.createChildNode(
                    withName: "formica_rufa_\(index)",
                    modelURL: childModelURL,
                    textureName: "AntTexture",
                    specularPower: 40,
                    specularColor: float3(0.8, 0.8, 0.8),
                    device: device,
                    vertexDescriptor: vertexDescriptor,
                    bufferAllocator: bufferAllocator,
                    textureLoader: textureLoader) {

                    centralNode.children.append(node)
                }
            }
        } catch let error {
            fatalError("\(error)")
        }

        return scene
    }

    func touchDragged(at point: CGPoint) {
        guard touchDown else {
            return
        }

        scene.updateOrbit(float2(
            Float(point.x - touchDownPoint.x),
            Float(point.y - touchDownPoint.y)
        ))
    }

    func touchDown(at point: CGPoint) {
        touchDown = true
        touchDownPoint = point
    }

    func touchUp() {
        touchDown = false
    }
}

extension Renderer: MTKViewDelegate {
    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }

    func draw(in view: MTKView) {
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        time += 1 / Float(view.preferredFramesPerSecond)
        scene.update(time: time, aspectRatio: aspectRatio, pan: touchDown, zoomIn: false, zoomOut: false)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("command buffer not available")
            return
        }

        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 222.0 / 255.0, 173.00 / 255.0, 1.0)
            guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                print("Unable te create command encoder not available.\nMake sure to call endEncoding() before creating another encoder.")
                return
            }

            commandEncoder.setFrontFacing(.counterClockwise)
            commandEncoder.setCullMode(.back)
            commandEncoder.setDepthStencilState(depthStencilState)
            commandEncoder.setRenderPipelineState(renderPipeline)
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)

            scene.drawRecursive(
                node: scene.rootNode,
                parentTransform: matrix_identity_float4x4,
                commandEncoder: commandEncoder
            )

            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
