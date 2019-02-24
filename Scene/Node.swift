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
