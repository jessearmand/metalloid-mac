//
//  ViewController.swift
//  Metaloid
//
//  Created by Jesse Armand on 17/2/19.
//  Copyright © 2019 Jesse Armand. All rights reserved.
//

import Cocoa
import MetalKit

final class MetalViewController: NSViewController {
    var device: MTLDevice?

    lazy var mtkView: MTKView = {
        device = MTLCreateSystemDefaultDevice()

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        return mtkView
    }()

    lazy var renderer: Renderer = {
        let renderer = Renderer(withView: mtkView, device: device)
        return renderer
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        if let metalLayer = view.layer as? CAMetalLayer {
            metalLayer.framebufferOnly = false
        }

        view.addSubview(mtkView)
        mtkView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        mtkView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        mtkView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        mtkView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        mtkView.delegate = renderer
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

