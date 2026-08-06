import SceneKit
import SwiftUI

enum OrbState: Equatable {
    case idle
    case active

    struct AnimationParameters {
        let rotationSpeed: Double   // radians per second
        let glowIntensity: Double   // 0...1
    }

    var animationParameters: AnimationParameters {
        switch self {
        case .idle:
            return AnimationParameters(rotationSpeed: 0.15, glowIntensity: 0.35)
        case .active:
            return AnimationParameters(rotationSpeed: 0.6, glowIntensity: 0.85)
        }
    }
}

struct OrbView: NSViewRepresentable {
    let state: OrbState

    final class Coordinator {
        var lastAppliedState: OrbState?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = Self.makeScene()
        view.backgroundColor = .clear
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
        applyState(state, to: view)
        context.coordinator.lastAppliedState = state
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard context.coordinator.lastAppliedState != state else { return }
        applyState(state, to: view)
        context.coordinator.lastAppliedState = state
    }

    private func applyState(_ state: OrbState, to view: SCNView) {
        guard let orbNode = view.scene?.rootNode.childNode(withName: "orb", recursively: false) else { return }
        let params = state.animationParameters

        orbNode.removeAction(forKey: "rotate")
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat(params.rotationSpeed) * .pi, z: 0, duration: 1.0)
        rotateAction.timingMode = .easeInEaseOut
        let rotation = SCNAction.repeatForever(rotateAction)
        orbNode.runAction(rotation, forKey: "rotate")

        if let glowNode = view.scene?.rootNode.childNode(withName: "glow", recursively: false),
           let material = glowNode.geometry?.firstMaterial {
            material.emission.intensity = CGFloat(params.glowIntensity)
        }
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()

        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 24 // faceted, globe-like rather than perfectly smooth
        sphere.firstMaterial?.diffuse.contents = NSColor.controlAccentColor
        sphere.firstMaterial?.specular.contents = NSColor.white
        let orbNode = SCNNode(geometry: sphere)
        orbNode.name = "orb"
        scene.rootNode.addChildNode(orbNode)

        let glowSphere = SCNSphere(radius: 1.25)
        // Diffuse must be fully OPAQUE (alpha 1) black — under `.aOne` transparency mode the
        // diffuse alpha channel *is* the material's opacity, so `.clear` (alpha 0) made the
        // entire glow sphere invisible regardless of emission. Black diffuse contributes no
        // reflected light of its own, while alpha 1 lets the additive emission actually render.
        glowSphere.firstMaterial?.diffuse.contents = NSColor.black
        glowSphere.firstMaterial?.emission.contents = NSColor.controlAccentColor
        glowSphere.firstMaterial?.emission.intensity = 0.35
        glowSphere.firstMaterial?.transparencyMode = .aOne
        glowSphere.firstMaterial?.blendMode = .add
        glowSphere.firstMaterial?.lightingModel = .constant // glow shouldn't itself be lit/shaded
        let glowNode = SCNNode(geometry: glowSphere)
        glowNode.name = "glow"
        scene.rootNode.addChildNode(glowNode)

        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4)
        scene.rootNode.addChildNode(cameraNode)

        // Key light: gives the sphere a clear highlight + shading gradient so it reads as a
        // 3D form rather than a flat-shaded dot, even at icon size.
        let keyLight = SCNLight()
        keyLight.type = .omni
        keyLight.intensity = 900
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(2, 2, 4)
        scene.rootNode.addChildNode(keyLightNode)

        // Ambient fill so the shadowed side of the sphere isn't pure black at this small size.
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 250
        ambientLight.color = NSColor.controlAccentColor
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        return scene
    }
}
