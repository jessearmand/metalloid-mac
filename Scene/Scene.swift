//
//  Scene.swift
//  Metaloid
//
//  Created by Jesse Armand on 23/2/19.
//  Copyright © 2019 Jesse Armand. All rights reserved.
//

import MetalKit

struct Light {
    var worldPosition = float3(0, 0, 0)
    var color = float3(0, 0, 0)
}

final class Material {
    var specularColor = float3(1, 1, 1)
    var specularPower = Float(1)
    var baseColorTexture: MTLTexture?
}

final class Scene {
    var cameraWorldPosition = float3(0, 0, 2)
    var viewMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4
    var rootNode: Node = Node(name: "Root")
    var ambientLightColor = float3(0, 0, 0)
    var lights: [Light] = []
}

extension Scene {
    func update(time: Float, aspectRatio: Float) {
        projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi/3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)

        let angle = time
        viewMatrix = float4x4(translationBy: -cameraWorldPosition) * float4x4(rotationAbout: float3(0, 1, 0), by: angle)

        let modelMatrix = float4x4(scaleBy: 1.0)
        rootNode.modelMatrix = modelMatrix
    }

    func drawRecursive(node: Node,
                       parentTransform: float4x4,
                       commandEncoder: MTLRenderCommandEncoder) {
        let modelMatrix = parentTransform * node.modelMatrix
        let viewProjectionMatrix = projectionMatrix * viewMatrix

        var vertexUniforms = VertexUniforms(
            viewProjectionMatrix: viewProjectionMatrix,
            modelMatrix: modelMatrix,
            normalMatrix: modelMatrix.normalMatrix
        )
        commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)

        var fragmentUniforms = FragmentUniforms(cameraWorldPosition: cameraWorldPosition,
                                                ambientLightColor: float3(0.1, 0.1, 0.1),
                                                specularColor: node.material.specularColor,
                                                specularPower: node.material.specularPower,
                                                light0: lights[0],
                                                light1: lights[1],
                                                light2: lights[2])
        commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)
        commandEncoder.setFragmentTexture(node.material.baseColorTexture, index: 0)

        if let mesh = node.mesh {
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
                parentTransform: parentTransform,
                commandEncoder: commandEncoder
            )
        }
    }
}
