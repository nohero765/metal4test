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
    private var lastTime: CFTimeInterval?

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
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { event in
            if event.type == .keyDown && event.keyCode == 49 {
                self.renderer.handleJump()
                return nil
            }
            if event.type == .keyDown && event.keyCode == 15 {
                self.renderer.handleRestart()
                return nil
            }
            if event.type == .leftMouseDown {
                self.renderer.handleJump()
            }
            return event
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let now = CACurrentMediaTime()
        let delta = min(max(now - (lastTime ?? now), 0), 1 / 20)
        lastTime = now
        renderer.update(deltaTime: Float(delta))
        super.draw(dirtyRect)
    }
}
