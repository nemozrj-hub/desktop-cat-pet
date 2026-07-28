import AppKit

struct Atlas: Decodable {
    struct Size: Decodable {
        let width: CGFloat
        let height: CGFloat
    }

    struct Point: Decodable {
        let x: CGFloat
        let y: CGFloat
    }

    struct Frame: Decodable {
        let x: CGFloat
        let y: CGFloat
        let w: CGFloat
        let h: CGFloat
    }

    struct Animation: Decodable {
        let fps: Double
        let loop: Bool
        let anchor: Point
        let frames: [Frame]
    }

    let image: String
    let atlasSize: Size
    let frameSize: Size
    let animations: [String: Animation]
}

enum PetState: String {
    case idle = "idle_front"
    case walkRight = "walk_right"
    case walkLeft = "walk_left"
    case clicked = "clicked_happy"
    case dragged
    case sleep
}

final class SpriteAtlas {
    let atlas: Atlas
    let image: NSImage

    init() throws {
        let bundle = Bundle.module
        guard let jsonURL = bundle.url(forResource: "cat_desktop_pet_sprite_sheet", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: jsonURL)
        self.atlas = try JSONDecoder().decode(Atlas.self, from: data)

        guard let imageURL = bundle.url(forResource: "cat_desktop_pet_sprite_sheet", withExtension: "png"),
              let loadedImage = NSImage(contentsOf: imageURL) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.image = loadedImage
    }

    func animation(_ state: PetState) -> Atlas.Animation {
        atlas.animations[state.rawValue] ?? atlas.animations[PetState.idle.rawValue]!
    }
}

final class PetView: NSView {
    private let spriteAtlas: SpriteAtlas
    private(set) var state: PetState = .idle
    private var frameIndex = 0
    private var frameAccumulator: TimeInterval = 0
    private var lastTick = Date()
    private var completion: (() -> Void)?
    private var isMouseDragging = false
    private var dragStartInWindow = NSPoint.zero
    private var dragStartWindowOrigin = NSPoint.zero
    private var mouseDownScreenPoint = NSPoint.zero
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onClick: (() -> Void)?

    init(spriteAtlas: SpriteAtlas) {
        self.spriteAtlas = spriteAtlas
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: 220, height: 220)))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool {
        false
    }

    func setState(_ newState: PetState, completion: (() -> Void)? = nil) {
        guard state != newState || !spriteAtlas.animation(newState).loop else { return }
        state = newState
        frameIndex = 0
        frameAccumulator = 0
        lastTick = Date()
        self.completion = completion
        needsDisplay = true
    }

    func tick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastTick)
        lastTick = now

        let animation = spriteAtlas.animation(state)
        let frameDuration = 1.0 / max(animation.fps, 1.0)
        frameAccumulator += delta

        while frameAccumulator >= frameDuration {
            frameAccumulator -= frameDuration
            frameIndex += 1

            if frameIndex >= animation.frames.count {
                if animation.loop {
                    frameIndex = 0
                } else {
                    frameIndex = max(animation.frames.count - 1, 0)
                    let finished = completion
                    completion = nil
                    finished?()
                    break
                }
            }
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let animation = spriteAtlas.animation(state)
        guard !animation.frames.isEmpty else { return }

        let frame = animation.frames[min(frameIndex, animation.frames.count - 1)]
        let sourceY = spriteAtlas.atlas.atlasSize.height - frame.y - frame.h
        let sourceRect = NSRect(x: frame.x, y: sourceY, width: frame.w, height: frame.h)

        spriteAtlas.image.draw(
            in: bounds,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        isMouseDragging = false
        dragStartInWindow = event.locationInWindow
        dragStartWindowOrigin = window.frame.origin
        mouseDownScreenPoint = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let currentScreenPoint = NSEvent.mouseLocation
        let delta = NSPoint(
            x: currentScreenPoint.x - mouseDownScreenPoint.x,
            y: currentScreenPoint.y - mouseDownScreenPoint.y
        )

        if !isMouseDragging && hypot(delta.x, delta.y) > 3 {
            isMouseDragging = true
            onDragStart?()
        }

        guard isMouseDragging else { return }
        let newOrigin = NSPoint(
            x: dragStartWindowOrigin.x + delta.x,
            y: dragStartWindowOrigin.y + delta.y
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if isMouseDragging {
            isMouseDragging = false
            onDragEnd?()
        } else {
            onClick?()
        }
    }
}

final class PetController {
    private enum Mode {
        case idle
        case walking(direction: CGFloat, until: Date)
        case sleeping(until: Date)
        case userControlled
    }

    private let spriteAtlas: SpriteAtlas
    private let petView: PetView
    private let panel: NSPanel
    private var animationTimer: Timer?
    private var behaviorTimer: Timer?
    private var movementTimer: Timer?
    private var mode: Mode = .idle
    private var lastMovementTick = Date()
    private let defaults = UserDefaults.standard
    private var scale: CGFloat {
        CGFloat(defaults.double(forKey: "pet.scale").nonZero(default: 0.43))
    }

    init() throws {
        self.spriteAtlas = try SpriteAtlas()
        self.petView = PetView(spriteAtlas: spriteAtlas)
        self.panel = NSPanel(
            contentRect: NSRect(x: 240, y: 240, width: 220, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        configureCallbacks()
        restoreFrame()
    }

    func show() {
        panel.orderFrontRegardless()
        startTimers()
    }

    func toggleVisibility() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func setScale(_ newScale: CGFloat) {
        defaults.set(Double(newScale), forKey: "pet.scale")
        let currentFrame = panel.frame
        panel.setFrame(
            NSRect(origin: currentFrame.origin, size: NSSize(width: 512 * newScale, height: 512 * newScale)),
            display: true
        )
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        defaults.set(enabled, forKey: "pet.alwaysOnTop")
        panel.level = enabled ? .screenSaver : .floating
    }

    func enterSleep() {
        mode = .sleeping(until: Date().addingTimeInterval(12))
        petView.setState(.sleep)
    }

    func wakeUp() {
        mode = .idle
        petView.setState(.idle)
    }

    func savePosition() {
        defaults.set(Double(panel.frame.origin.x), forKey: "pet.origin.x")
        defaults.set(Double(panel.frame.origin.y), forKey: "pet.origin.y")
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.contentView = petView
        panel.level = defaults.object(forKey: "pet.alwaysOnTop") as? Bool == true ? .screenSaver : .floating
        panel.ignoresMouseEvents = false
        panel.setFrame(NSRect(x: 240, y: 240, width: 512 * scale, height: 512 * scale), display: false)
    }

    private func configureCallbacks() {
        petView.onClick = { [weak self] in
            self?.playClicked()
        }
        petView.onDragStart = { [weak self] in
            self?.mode = .userControlled
            self?.petView.setState(.dragged)
        }
        petView.onDragEnd = { [weak self] in
            self?.savePosition()
            self?.mode = .idle
            self?.petView.setState(.idle)
        }
    }

    private func restoreFrame() {
        let savedX = defaults.object(forKey: "pet.origin.x") as? Double
        let savedY = defaults.object(forKey: "pet.origin.y") as? Double
        if let savedX, let savedY {
            panel.setFrameOrigin(NSPoint(x: savedX, y: savedY))
        } else if let screen = NSScreen.main {
            let frame = panel.frame
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.midX - frame.width / 2, y: visible.minY + 48))
        }
    }

    private func startTimers() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.petView.tick()
        }
        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.moveIfNeeded()
        }
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.chooseNextBehavior()
        }
    }

    private func chooseNextBehavior() {
        switch mode {
        case .userControlled:
            return
        case .walking(_, let until):
            if Date() < until { return }
        case .sleeping(let until):
            if Date() < until { return }
        case .idle:
            break
        }

        let roll = Int.random(in: 0..<100)
        if roll < 18 {
            enterSleep()
        } else if roll < 66 {
            let direction: CGFloat = Bool.random() ? 1 : -1
            mode = .walking(direction: direction, until: Date().addingTimeInterval(Double.random(in: 3.0...6.5)))
            petView.setState(direction > 0 ? .walkRight : .walkLeft)
        } else {
            mode = .idle
            petView.setState(.idle)
        }
    }

    private func moveIfNeeded() {
        let now = Date()
        let delta = now.timeIntervalSince(lastMovementTick)
        lastMovementTick = now

        guard case .walking(let direction, _) = mode else { return }
        let speed: CGFloat = 58
        var frame = panel.frame
        frame.origin.x += direction * speed * CGFloat(delta)

        let bounds = Self.combinedVisibleFrame()
        if frame.minX < bounds.minX {
            frame.origin.x = bounds.minX
            mode = .walking(direction: 1, until: Date().addingTimeInterval(4))
            petView.setState(.walkRight)
        } else if frame.maxX > bounds.maxX {
            frame.origin.x = bounds.maxX - frame.width
            mode = .walking(direction: -1, until: Date().addingTimeInterval(4))
            petView.setState(.walkLeft)
        }

        frame.origin.y = max(bounds.minY, min(frame.origin.y, bounds.maxY - frame.height))
        panel.setFrameOrigin(frame.origin)
        savePosition()
    }

    private func playClicked() {
        mode = .userControlled
        petView.setState(.clicked) { [weak self] in
            self?.mode = .idle
            self?.petView.setState(.idle)
        }
    }

    private static func combinedVisibleFrame() -> NSRect {
        NSScreen.screens.map(\.visibleFrame).reduce(NSScreen.main?.visibleFrame ?? .zero) { partial, next in
            partial.union(next)
        }
    }
}

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let petController: PetController

    init(petController: PetController) {
        self.petController = petController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configure()
    }

    private func configure() {
        statusItem.button?.title = "Cat"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示 / 隐藏", action: #selector(toggleVisibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "睡觉", action: #selector(sleep), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "醒来", action: #selector(wake), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let scaleMenu = NSMenu()
        for item in [(0.32, "小"), (0.43, "中"), (0.56, "大"), (0.72, "超大")] {
            let menuItem = NSMenuItem(title: item.1, action: #selector(scale(_:)), keyEquivalent: "")
            menuItem.representedObject = item.0
            scaleMenu.addItem(menuItem)
        }
        let scaleRoot = NSMenuItem(title: "大小", action: nil, keyEquivalent: "")
        menu.setSubmenu(scaleMenu, for: scaleRoot)
        menu.addItem(scaleRoot)

        let topItem = NSMenuItem(title: "始终置顶", action: #selector(toggleAlwaysOnTop(_:)), keyEquivalent: "")
        topItem.state = UserDefaults.standard.bool(forKey: "pet.alwaysOnTop") ? .on : .off
        menu.addItem(topItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        scaleMenu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func toggleVisibility() {
        petController.toggleVisibility()
    }

    @objc private func sleep() {
        petController.enterSleep()
    }

    @objc private func wake() {
        petController.wakeUp()
    }

    @objc private func scale(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double {
            petController.setScale(CGFloat(value))
        }
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        let enabled = sender.state != .on
        sender.state = enabled ? .on : .off
        petController.setAlwaysOnTop(enabled)
    }

    @objc private func quit() {
        petController.savePosition()
        NSApp.terminate(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petController: PetController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            let petController = try PetController()
            self.petController = petController
            self.menuBarController = MenuBarController(petController: petController)
            petController.show()
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "桌宠启动失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        petController?.savePosition()
    }
}

extension Double {
    func nonZero(default fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
