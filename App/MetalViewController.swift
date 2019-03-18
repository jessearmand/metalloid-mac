//
//  ViewController.swift
//  Metaloid
//
//  Created by Jesse Armand on 17/2/19.
//  Copyright © 2019 Jesse Armand. All rights reserved.
//

import Cocoa
import MetalKit

struct MetalViewComponents {
    static func createView(withFrame frame: CGRect, device: MTLDevice) -> MTKView {
        let mtkView = MTKView(frame: frame, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        return mtkView
    }

    static func createRenderer(with view: MTKView) -> Renderer {
        let renderer = Renderer(withView: view)
        return renderer
    }
}

final class MetalViewController: NSViewController {
    let device: MTLDevice
    let mtkView: MTKView
    let renderer: Renderer

    required init?(coder: NSCoder) {
        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("No metal device was created")
        }

        device = mtlDevice

        let windowFrame = NSApplication.shared.keyWindow?.frame ?? .zero
        mtkView = MetalViewComponents.createView(withFrame: windowFrame, device: device)
        renderer = MetalViewComponents.createRenderer(with: mtkView)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let metalLayer = mtkView.layer as? CAMetalLayer {
            metalLayer.framebufferOnly = false
        }

        view.addSubview(mtkView)
        mtkView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        mtkView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        mtkView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        mtkView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }

    override func mouseUp(with event: NSEvent) {
        renderer.touchUp()
    }

    override func mouseDown(with event: NSEvent) {
        let mouseDownPoint = event.locationInWindow
        renderer.touchDown(at: mouseDownPoint)
    }

    override func mouseDragged(with event: NSEvent) {
        let draggedPoint = event.locationInWindow
        renderer.touchDragged(at: draggedPoint)
    }
}

