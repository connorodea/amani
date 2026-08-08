import SceneKit
import SwiftUI

/// A fixed, deliberately-chosen accent — not `NSColor.controlAccentColor`, which reflects
/// whatever the user happens to have set in System Settings (blue, purple, pink, graphite...)
/// and made the orb's color an accident of each Mac's configuration rather than a real design
/// choice. A restrained, rare accent color (used here and almost nowhere else in the app) is
/// deliberate — sourced from ui-ux-pro-max's design-system guidance for developer-tool/launcher
/// products, which converges on a single fixed accent against an otherwise neutral palette.
private let orbAccent = NSColor(calibratedRed: 0.35, green: 0.43, blue: 0.98, alpha: 1.0)

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
            return AnimationParameters(rotationSpeed: 0.08, glowIntensity: 0.12)
        case .active:
            return AnimationParameters(rotationSpeed: 0.35, glowIntensity: 0.3)
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

        // A slow, continuous rotation is the orb's only constant motion — a "rhythmic,
        // moon-like" quality per the original design intent. A prior version also added a
        // continuous breathing scale-pulse on top of this; removed. A shape that's
        // perpetually rotating AND pulsing AND glowing reads as an attention-grabbing toy,
        // not a restrained status indicator — closer to a bouncing mascot than the
        // Vercel/Anthropic/Apple/OpenAI-level restraint this app is aiming for. Rotation
        // alone, slow and quiet, still conveys "alive" without that.
        orbNode.removeAction(forKey: "rotate")
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat(params.rotationSpeed) * .pi, z: 0, duration: 1.0)
        rotateAction.timingMode = .easeInEaseOut
        let rotation = SCNAction.repeatForever(rotateAction)
        orbNode.runAction(rotation, forKey: "rotate")
        orbNode.removeAction(forKey: "breathe")

        if let glowNode = view.scene?.rootNode.childNode(withName: "glow", recursively: false),
           let material = glowNode.geometry?.firstMaterial {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.25
            material.emission.intensity = CGFloat(params.glowIntensity)
            SCNTransaction.commit()
        }
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()

        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 32 // faceted, globe-like rather than perfectly smooth
        let orbMaterial = sphere.firstMaterial
        orbMaterial?.lightingModel = .physicallyBased
        orbMaterial?.diffuse.contents = orbAccent
        orbMaterial?.metalness.contents = 0.2
        orbMaterial?.roughness.contents = 0.45
        let orbNode = SCNNode(geometry: sphere)
        orbNode.name = "orb"
        scene.rootNode.addChildNode(orbNode)

        let glowSphere = SCNSphere(radius: 1.25)
        // Diffuse must be fully OPAQUE (alpha 1) black — under `.aOne` transparency mode the
        // diffuse alpha channel *is* the material's opacity, so `.clear` (alpha 0) made the
        // entire glow sphere invisible regardless of emission. Black diffuse contributes no
        // reflected light of its own, while alpha 1 lets the additive emission actually render.
        glowSphere.firstMaterial?.diffuse.contents = NSColor.black
        glowSphere.firstMaterial?.emission.contents = orbAccent
        glowSphere.firstMaterial?.emission.intensity = 0.12
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
        keyLight.intensity = 1100
        keyLight.color = NSColor.white
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(2, 2, 4)
        scene.rootNode.addChildNode(keyLightNode)

        // Cool rim light from the opposite side — a classic two-light setup that separates the
        // sphere's edge from its own base color instead of one flat warm highlight, giving it
        // more visible dimension at a small render size.
        let rimLight = SCNLight()
        rimLight.type = .omni
        rimLight.intensity = 500
        rimLight.color = NSColor(calibratedRed: 0.55, green: 0.75, blue: 1.0, alpha: 1.0)
        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(-2.5, -1, 2.5)
        scene.rootNode.addChildNode(rimLightNode)

        // Ambient fill so the shadowed side of the sphere isn't pure black at this small size.
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 200
        ambientLight.color = orbAccent
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        return scene
    }
}
