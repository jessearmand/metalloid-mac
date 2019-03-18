//
//  Scene.swift
//  Metaloid
//
//  Created by Jesse Armand on 23/2/19.
//  Copyright © 2019 Jesse Armand. All rights reserved.
//

import MetalKit

struct Light {
    let worldPosition: float3
    let color: float3
}

final class Material {
    var specularColor = float3(1, 1, 1)
    var specularPower = Float(1)
    var baseColorTexture: MTLTexture?
}

final class Camera {
    fileprivate var orbit = float2(0, 0)
    var cameraAngles = float2(0, 0)
    var cameraWorldPosition = float3(0, 0, 3)

    func updateAngles() {
        cameraAngles = float2(
            cameraAngles.x + (0.001 * orbit.y),
            cameraAngles.y + (0.001 * orbit.x)
        )
    }
}

final class Scene {
    var camera = Camera()
    var viewMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4
    var rootNode: Node = Node(name: "Root")
    var ambientLightColor = float3(0, 0, 0)
    var lights: [Light] = []

    func updateOrbit(_ orbit: float2) {
        camera.orbit = orbit
    }
}

extension Scene {
    func update(time: Float, aspectRatio: Float, pan: Bool, zoomIn: Bool, zoomOut: Bool) {
        if pan {
            camera.updateAngles()
        }

        viewMatrix = float4x4(translationBy: -camera.cameraWorldPosition) *
            float4x4(rotationAbout: float3(1, 0, 0), by: camera.cameraAngles.x) *
            float4x4(rotationAbout: float3(0, 1, 0), by: camera.cameraAngles.y)
        projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 6, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)

        if let centralNode = rootNode.nodeNamedRecursive("formica_rufa") {
            centralNode.modelMatrix = float4x4(scaleBy: 0.5)
        }

        let childNodeBaseTransform =
            float4x4(rotationAbout: float3(0, 0, 1), by: -.pi / 2) *
            float4x4(scaleBy: 0.25) *
            float4x4(rotationAbout: float3(0, 1, 0), by: -.pi / 2)

        for index in 1...Renderer.childNodeCount {
            if let childNode = rootNode.nodeNamedRecursive("formica_rufa_\(index)") {
                let pivotPosition = float3(0.4, 0, 0)
                let rotationOffset = float3(2.4, 0, 0)
                let rotationSpeed = Float(0.3)
                let rotationAngle = 2 * Float.pi * Float(rotationSpeed * time) + (2 * .pi / Float(Renderer.childNodeCount) * Float(index - 1))
                let horizontalAngle = 2 * .pi / Float(Renderer.childNodeCount) * Float(index - 1)
                childNode.modelMatrix = float4x4(rotationAbout: float3(0, 1, 0), by: horizontalAngle) *
                    float4x4(translationBy: rotationOffset) *
                    float4x4(rotationAbout: float3(0, 0, 1), by: rotationAngle) *
                    float4x4(translationBy: pivotPosition) *
                childNodeBaseTransform
            }
        }
    }

    func drawRecursive(node: Node, parentTransform: float4x4, commandEncoder: MTLRenderCommandEncoder) {
        let modelMatrix = parentTransform * node.modelMatrix

        if let mesh = node.mesh, let baseColorTexture = node.material.baseColorTexture {
            let viewProjectionMatrix = projectionMatrix * viewMatrix

            var vertexUniforms = VertexUniforms(
                viewProjectionMatrix: viewProjectionMatrix,
                modelMatrix: modelMatrix,
                normalMatrix: modelMatrix.normalMatrix
            )
            commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)

            var fragmentUniforms = FragmentUniforms(cameraWorldPosition: camera.cameraWorldPosition,
                                                    ambientLightColor: ambientLightColor,
                                                    specularColor: node.material.specularColor,
                                                    specularPower: node.material.specularPower,
                                                    light0: lights[0],
                                                    light1: lights[1],
                                                    light2: lights[2])
            commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)
            commandEncoder.setFragmentTexture(baseColorTexture, index: 0)

            guard let vertexBuffer = mesh.vertexBuffers.first else {
                fatalError("mesh vertex buffers is empty")
            }

            commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)

            for submesh in mesh.submeshes {
                commandEncoder.drawIndexedPrimitives(
                    type: submesh.primitiveType,
                    indexCount: submesh.indexCount,
                    indexType: submesh.indexType,
                    indexBuffer: submesh.indexBuffer.buffer,
                    indexBufferOffset: submesh.indexBuffer.offset
                )
            }
        }

        for child in node.children {
            drawRecursive(
                node: child,
                parentTransform: modelMatrix,
                commandEncoder: commandEncoder
            )
        }
    }
}
