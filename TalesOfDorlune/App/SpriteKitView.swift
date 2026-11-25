import SpriteKit
import SwiftUI

/// Hosts an SKView and cross-fades whenever the scene changes (map to map, into and out of battle),
/// except walking over a border into the land next door, which was on screen already.
struct SpriteKitView: UIViewRepresentable {
    let scene: SKScene
    /// Settings → Developer's frame rate, nodes and draw calls, in any build.
    @AppStorage(GameSettings.devStatsKey) private var showsStats = false

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        #if DEBUG
        // Not while filming the App Store preview (debug `demo`) or shooting its screenshots (`clean`).
        if !DebugLaunch.hidesFrameCounter {
            view.showsFPS = true
            view.showsNodeCount = true
        }
        #endif
        showStats(on: view)
        view.presentScene(scene)
        return view
    }

    /// The counters in the corner while Settings → Developer asks for them (debug builds show them anyway).
    private func showStats(on view: SKView) {
        #if DEBUG
        if !DebugLaunch.hidesFrameCounter { return }
        #endif
        view.showsFPS = showsStats
        view.showsNodeCount = showsStats
        view.showsDrawCount = showsStats
    }

    func updateUIView(_ view: SKView, context: Context) {
        showStats(on: view)
        guard view.scene !== scene else { return }
        let transition: SKTransition = scene is BattleScene
            ? .fade(with: .white, duration: 0.45)
            : .fade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)
    }
}
