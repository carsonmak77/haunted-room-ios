import SpriteKit

final class GameScene: SKScene {
    private let engine: GameEngine
    private var lastUpdateTime: TimeInterval = 0
    private var isLayoutBuilt = false

    private let bedNode = SKNode()
    private let bedLevelLabel = SKLabelNode()
    private let doorNode = SKNode()
    private let doorShape = SKShapeNode()
    private let doorLevelLabel = SKLabelNode()
    private let doorHealthLabel = SKLabelNode()
    private let ghostNode = SKNode()
    private let ghostHealthBar = SKShapeNode()
    private let ghostHealthLabel = SKLabelNode()
    private let waveLabel = SKLabelNode()
    private let statusLabel = SKLabelNode()
    private let waveBanner = SKLabelNode()

    private var turretNodes: [SKNode] = []
    private var turretBases: [SKShapeNode] = []
    private var turretIcons: [SKLabelNode] = []
    private var turretLevelLabels: [SKLabelNode] = []

    private let doorPosition = CGPoint(x: 337, y: 240)
    private let ghostPosition = CGPoint(x: 320, y: 385)
    private let turretPositions = [
        CGPoint(x: 205, y: 350),
        CGPoint(x: 275, y: 330),
        CGPoint(x: 205, y: 145),
        CGPoint(x: 275, y: 125)
    ]

    init(engine: GameEngine) {
        self.engine = engine
        super.init(size: CGSize(width: 390, height: 480))
        scaleMode = .aspectFit
        backgroundColor = UIColor(red: 0.035, green: 0.045, blue: 0.09, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        guard !isLayoutBuilt else { return }
        isLayoutBuilt = true
        buildLayout()
        synchronizeNodes()
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        if lastUpdateTime > 0 {
            let delta = max(0, min(currentTime - lastUpdateTime, 0.1))
            engine.advance(dt: delta * engine.state.debug.speedMultiplier)
        }
        synchronizeNodes()
        handleEvents(engine.drainEvents())
    }

    private func buildLayout() {
        let room = SKShapeNode(rectOf: CGSize(width: 360, height: 420), cornerRadius: 20)
        room.position = CGPoint(x: 195, y: 240)
        room.fillColor = UIColor(red: 0.09, green: 0.11, blue: 0.18, alpha: 1)
        room.strokeColor = UIColor(red: 0.27, green: 0.31, blue: 0.45, alpha: 1)
        room.lineWidth = 3
        addChild(room)

        for y in stride(from: 70, through: 410, by: 68) {
            let line = SKShapeNode(rectOf: CGSize(width: 340, height: 1))
            line.position = CGPoint(x: 195, y: CGFloat(y))
            line.fillColor = UIColor.white.withAlphaComponent(0.035)
            line.strokeColor = .clear
            addChild(line)
        }

        configure(label: waveLabel, size: 17, bold: true)
        waveLabel.position = CGPoint(x: 195, y: 440)
        addChild(waveLabel)

        configure(label: statusLabel, size: 14, bold: false)
        statusLabel.fontColor = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1)
        statusLabel.position = CGPoint(x: 185, y: 405)
        addChild(statusLabel)

        buildWindow()
        buildBed()
        buildDoor()
        buildGhost()
        buildTurrets()

        configure(label: waveBanner, size: 30, bold: true)
        waveBanner.position = CGPoint(x: 195, y: 270)
        waveBanner.fontColor = .white
        waveBanner.zPosition = 20
        waveBanner.alpha = 0
        addChild(waveBanner)
    }

    private func buildWindow() {
        let window = SKShapeNode(rectOf: CGSize(width: 84, height: 70), cornerRadius: 10)
        window.position = CGPoint(x: 85, y: 365)
        window.fillColor = UIColor(red: 0.03, green: 0.08, blue: 0.17, alpha: 1)
        window.strokeColor = UIColor(red: 0.25, green: 0.45, blue: 0.65, alpha: 1)
        window.lineWidth = 3
        addChild(window)

        let moon = SKLabelNode(text: "☾")
        moon.fontSize = 34
        moon.fontColor = UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)
        moon.position = CGPoint(x: 0, y: -15)
        window.addChild(moon)
    }

    private func buildBed() {
        bedNode.position = CGPoint(x: 105, y: 235)
        addChild(bedNode)

        let frame = SKShapeNode(rectOf: CGSize(width: 136, height: 82), cornerRadius: 12)
        frame.fillColor = UIColor(red: 0.15, green: 0.38, blue: 0.65, alpha: 1)
        frame.strokeColor = UIColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1)
        frame.lineWidth = 3
        bedNode.addChild(frame)

        let pillow = SKShapeNode(rectOf: CGSize(width: 38, height: 58), cornerRadius: 9)
        pillow.position = CGPoint(x: -40, y: 0)
        pillow.fillColor = UIColor(red: 0.82, green: 0.9, blue: 1, alpha: 1)
        pillow.strokeColor = .clear
        bedNode.addChild(pillow)

        let player = SKLabelNode(text: "😴")
        player.fontSize = 42
        player.position = CGPoint(x: 19, y: -19)
        bedNode.addChild(player)

        configure(label: bedLevelLabel, size: 13, bold: true)
        bedLevelLabel.position = CGPoint(x: 0, y: -63)
        bedNode.addChild(bedLevelLabel)
    }

    private func buildDoor() {
        doorNode.position = doorPosition
        addChild(doorNode)

        let frame = SKShapeNode(rectOf: CGSize(width: 52, height: 136), cornerRadius: 7)
        frame.fillColor = UIColor(red: 0.25, green: 0.17, blue: 0.12, alpha: 1)
        frame.strokeColor = UIColor(red: 0.72, green: 0.5, blue: 0.25, alpha: 1)
        frame.lineWidth = 3
        doorNode.addChild(frame)

        doorShape.path = CGPath(
            roundedRect: CGRect(x: -20, y: -60, width: 40, height: 120),
            cornerWidth: 4,
            cornerHeight: 4,
            transform: nil
        )
        doorShape.fillColor = UIColor(red: 0.55, green: 0.34, blue: 0.18, alpha: 1)
        doorShape.strokeColor = .clear
        doorNode.addChild(doorShape)

        configure(label: doorLevelLabel, size: 14, bold: true)
        doorLevelLabel.position = CGPoint(x: 0, y: 18)
        doorNode.addChild(doorLevelLabel)

        configure(label: doorHealthLabel, size: 12, bold: false)
        doorHealthLabel.position = CGPoint(x: 0, y: -9)
        doorNode.addChild(doorHealthLabel)

        let knob = SKShapeNode(circleOfRadius: 3)
        knob.position = CGPoint(x: -12, y: -20)
        knob.fillColor = .yellow
        knob.strokeColor = .clear
        doorNode.addChild(knob)
    }

    private func buildGhost() {
        ghostNode.position = ghostPosition
        ghostNode.zPosition = 5
        addChild(ghostNode)

        let ghost = SKLabelNode(text: "👻")
        ghost.fontSize = 62
        ghost.position = CGPoint(x: 0, y: -15)
        ghostNode.addChild(ghost)

        let barBackground = SKShapeNode(rectOf: CGSize(width: 84, height: 8), cornerRadius: 4)
        barBackground.position = CGPoint(x: 0, y: -48)
        barBackground.fillColor = UIColor.black.withAlphaComponent(0.65)
        barBackground.strokeColor = .clear
        ghostNode.addChild(barBackground)

        ghostHealthBar.path = CGPath(
            roundedRect: CGRect(x: -40, y: -51, width: 80, height: 6),
            cornerWidth: 3,
            cornerHeight: 3,
            transform: nil
        )
        ghostHealthBar.fillColor = UIColor(red: 0.95, green: 0.25, blue: 0.35, alpha: 1)
        ghostHealthBar.strokeColor = .clear
        ghostNode.addChild(ghostHealthBar)

        configure(label: ghostHealthLabel, size: 11, bold: true)
        ghostHealthLabel.position = CGPoint(x: 0, y: -69)
        ghostNode.addChild(ghostHealthLabel)
    }

    private func buildTurrets() {
        for position in turretPositions {
            let node = SKNode()
            node.position = position
            addChild(node)

            let base = SKShapeNode(circleOfRadius: 27)
            base.strokeColor = UIColor.white.withAlphaComponent(0.25)
            base.lineWidth = 2
            node.addChild(base)

            let icon = SKLabelNode()
            configure(label: icon, size: 18, bold: true)
            icon.position = CGPoint(x: 0, y: -7)
            node.addChild(icon)

            let level = SKLabelNode()
            configure(label: level, size: 11, bold: false)
            level.position = CGPoint(x: 0, y: -43)
            node.addChild(level)

            turretNodes.append(node)
            turretBases.append(base)
            turretIcons.append(icon)
            turretLevelLabels.append(level)
        }
    }

    private func synchronizeNodes() {
        waveLabel.text = "第 \(engine.waveNumber) / \(engine.config.waves.count) 波"
        bedLevelLabel.text = "床铺 Lv.\(engine.state.bedLevel) · +\(engine.incomePerSecond)/秒"
        doorLevelLabel.text = "Lv.\(engine.state.doorLevel)"
        doorHealthLabel.text = "\(engine.state.doorHealth)"

        let doorRatio = Double(engine.state.doorHealth) / Double(engine.doorMaxHealth)
        if engine.state.debug.invincibleDoor {
            doorShape.fillColor = UIColor(red: 0.15, green: 0.65, blue: 0.75, alpha: 1)
        } else if doorRatio > 0.5 {
            doorShape.fillColor = UIColor(red: 0.55, green: 0.34, blue: 0.18, alpha: 1)
        } else {
            doorShape.fillColor = UIColor(red: 0.65, green: 0.2, blue: 0.18, alpha: 1)
        }

        for slot in turretNodes.indices {
            if let turret = engine.state.turrets[slot] {
                turretBases[slot].fillColor = UIColor(red: 0.8, green: 0.42, blue: 0.12, alpha: 1)
                turretBases[slot].strokeColor = UIColor(red: 1, green: 0.75, blue: 0.3, alpha: 1)
                turretIcons[slot].text = "炮"
                turretLevelLabels[slot].text = "Lv.\(turret.level)"
            } else {
                turretBases[slot].fillColor = UIColor.white.withAlphaComponent(0.05)
                turretBases[slot].strokeColor = UIColor.white.withAlphaComponent(0.25)
                turretIcons[slot].text = "＋"
                turretLevelLabels[slot].text = "炮台槽位"
            }
        }

        if let ghost = engine.state.ghost {
            ghostNode.isHidden = false
            let ratio = max(0, Double(ghost.health) / Double(ghost.maxHealth))
            ghostHealthBar.xScale = CGFloat(ratio)
            ghostHealthLabel.text = "\(ghost.health) / \(ghost.maxHealth)"
            statusLabel.text = "猛鬼正在进攻"
            statusLabel.fontColor = UIColor(red: 1, green: 0.55, blue: 0.55, alpha: 1)
        } else {
            ghostNode.isHidden = true
            ghostHealthLabel.text = ""
            if engine.state.phase == .playing {
                statusLabel.text = "安全间隙 · \(max(0, Int(ceil(engine.state.intermissionRemaining)))) 秒"
                statusLabel.fontColor = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1)
            } else {
                statusLabel.text = ""
            }
        }
    }

    private func handleEvents(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .shot(let slot):
                fireProjectile(from: slot)
            case .doorHit:
                shakeDoor()
            case .ghostDefeated(let wave):
                let reward = engine.config.waves[wave - 1].reward
                showFloatingText("击退！+\(reward) 金币", at: ghostPosition)
            case .waveStarted(let wave):
                showWaveBanner(wave)
            case .won, .lost:
                break
            }
        }
    }

    private func fireProjectile(from slot: Int) {
        guard turretPositions.indices.contains(slot) else { return }
        let projectile = SKShapeNode(circleOfRadius: 5)
        projectile.position = turretPositions[slot]
        projectile.fillColor = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        projectile.strokeColor = .clear
        projectile.zPosition = 10
        addChild(projectile)
        projectile.run(.sequence([
            .move(to: ghostPosition, duration: 0.12),
            .removeFromParent()
        ]))
    }

    private func shakeDoor() {
        doorNode.removeAction(forKey: "doorHit")
        let shake = SKAction.sequence([
            .moveBy(x: 4, y: 0, duration: 0.05),
            .moveBy(x: -8, y: 0, duration: 0.08),
            .moveBy(x: 4, y: 0, duration: 0.05)
        ])
        doorNode.run(.sequence([shake, .move(to: doorPosition, duration: 0)]), withKey: "doorHit")
    }

    private func showFloatingText(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(text: text)
        configure(label: label, size: 16, bold: true)
        label.fontColor = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        label.position = position
        label.zPosition = 15
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 45, duration: 0.8), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.45)])]),
            .removeFromParent()
        ]))
    }

    private func showWaveBanner(_ wave: Int) {
        waveBanner.removeAllActions()
        waveBanner.text = "第 \(wave) 波"
        waveBanner.alpha = 0
        waveBanner.run(.sequence([
            .fadeIn(withDuration: 0.15),
            .wait(forDuration: 0.65),
            .fadeOut(withDuration: 0.35)
        ]))
    }

    private func configure(label: SKLabelNode, size: CGFloat, bold: Bool) {
        label.fontName = bold ? "PingFangSC-Semibold" : "PingFangSC-Regular"
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
    }
}
