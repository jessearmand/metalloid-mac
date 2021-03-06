//
//  Node.swift
//  Metalloid
//
//  Created by Jesse Armand on 24/2/19.
//  Copyright © 2019 Jesse Armand. All rights reserved.
//

import Foundation
import MetalKit

final class Node {
    var name: String
    weak var parent: Node?
    var children: [Node] = []
    var modelMatrix = matrix_identity_float4x4
    var mesh: MTKMesh?
    var material = Material()

    init(name: String) {
        self.name = name
    }
}

extension Node {
    func nodeNamedRecursive(_ name: String) -> Node? {
        return children
            .compactMap { (node) -> Node? in
                if node.name == name {
                    return node
                }

                return node.nodeNamedRecursive(name)
            }
            .first
    }

    static func createChildNode(
        withName name: String,
        modelURL: URL?,
        textureName: String,
        specularPower: Float,
        specularColor: float3,
        device: MTLDevice,
        vertexDescriptor: MDLVertexDescriptor,
        bufferAllocator: MTKMeshBufferAllocator,
        textureLoader: MTKTextureLoader) throws -> Node {
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]

        let node = Node(name: name)
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        node.mesh = try MTKMesh.newMeshes(asset: asset, device: device).metalKitMeshes.first
        node.material.baseColorTexture = try textureLoader.newTexture(name: textureName, scaleFactor: 1.0, bundle: nil, options: options)
        node.material.specularPower = specularPower
        node.material.specularColor = specularColor
        return node
    }
}
