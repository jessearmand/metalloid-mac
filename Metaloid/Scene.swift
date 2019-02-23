//
//  Scene.swift
//  Metaloid
//
//  Created by Jesse Armand on 23/2/19.
//  Copyright © 2019 Jesse Armand. All rights reserved.
//

import simd
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
