import AppKit
import MetalKit

@main
final class NeonPulseApplication: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = GameView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Neon Pulse"
        window.contentView = view
        window.minSize = NSSize(width: 900, height: 520)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

final class GameView: MTKView {
    private let renderer: GameRenderer

    init(frame frameRect: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Neon Pulse requires a Metal-capable Mac")
        }
        renderer = GameRenderer(device: device)
        super.init(frame: frameRect, device: device)
        colorPixelFormat = .bgra8Unorm_srgb
        framebufferOnly = false
        preferredFramesPerSecond = 120
        enableSetNeedsDisplay = false
        isPaused = false
        delegate = renderer
        wantsLayer = true
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 {
            renderer.handleJump()
            return
        }
        if event.keyCode == 15 {
            renderer.handleRestart()
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        renderer.handleJump()
    }
}
