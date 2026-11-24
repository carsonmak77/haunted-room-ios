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
    private let waveLabel = SKLabelNode()
    private let statusLabel = SKLabelNode()
    private let waveBanner = SKLabelNode()

    private var turretNodes: [SKNode] = []
    private var turretBases: [SKShapeNode] = []
    private var turretIcons: [SKLabelNode] = []
    private var turretLevelLabels: [SKLabelNode] = []

    private var enemyNodes: [SKNode] = []
    private var enemyEmojiLabels: [SKLabelNode] = []
    private var enemyNameLabels: [SKLabelNode] = []
    private var enemyHealthFills: [SKShapeNode] = []

    private let doorPosition = CGPoint(x: 337, y: 240)
    private let enemyPositions: [CGPoint] = [
        CGPoint(x: 195, y: 408),
        CGPoint(x: 255, y: 408),
        CGPoint(x: 315, y: 408),
        CGPoint(x: 365, y: 408),
        CGPoint(x: 195, y: 372),
        CGPoint(x: 255, y: 372),
        CGPoint(x: 315, y: 372),
        CGPoint(x: 365, y: 372)
    ]
    private let turretPositions = [
        CGPoint(x: 165, y: 318),
        CGPoint(x: 225, y: 318),
        CGPoint(x: 165, y: 152),
        CGPoint(x: 225, y: 152)
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
        waveLabel.position = CGPoint(x: 195, y: 455)
        addChild(waveLabel)

        configure(label: statusLabel, size: 13, bold: false)
        statusLabel.fontColor = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1)
        statusLabel.position = CGPoint(x: 195, y: 432)
        addChild(statusLabel)

        buildWindow()
        buildBed()
        buildDoor()
        buildEnemies()
        buildTurrets()

        configure(label: waveBanner, size: 28, bold: true)
        waveBanner.position = CGPoint(x: 195, y: 268)
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

    private func buildEnemies() {
        for position in enemyPositions {
            let node = SKNode()
            node.position = position
            node.zPosition = 5
            addChild(node)

            let emoji = SKLabelNode(text: "")
            emoji.fontSize = 28
            emoji.verticalAlignmentMode = .center
            emoji.horizontalAlignmentMode = .center
            emoji.position = CGPoint(x: 0, y: 7)
            node.addChild(emoji)

            let name = SKLabelNode()
            configure(label: name, size: 9, bold: false)
            name.position = CGPoint(x: 0, y: -12)
            node.addChild(name)

            let barBackground = SKShapeNode(rectOf: CGSize(width: 46, height: 5), cornerRadius: 2.5)
            barBackground.position = CGPoint(x: 0, y: -24)
            barBackground.fillColor = UIColor.black.withAlphaComponent(0.6)
            barBackground.strokeColor = .clear
            node.addChild(barBackground)

            let fill = SKShapeNode()
            fill.path = CGPath(rect: CGRect(x: 0, y: -1.5, width: 42, height: 3), transform: nil)
            fill.position = CGPoint(x: -21, y: -24)
            fill.strokeColor = .clear
            node.addChild(fill)

            enemyNodes.append(node)
            enemyEmojiLabels.append(emoji)
            enemyNameLabels.append(name)
            enemyHealthFills.append(fill)
        }
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
            icon.fontSize = 18
            icon.verticalAlignmentMode = .center
            icon.horizontalAlignmentMode = .center
            icon.position = CGPoint(x: 0, y: 4)
            node.addChild(icon)

            let level = SKLabelNode()
            configure(label: level, size: 10, bold: false)
            level.position = CGPoint(x: 0, y: -17)
            node.addChild(level)

            turretNodes.append(node)
            turretBases.append(base)
            turretIcons.append(icon)
            turretLevelLabels.append(level)
        }
    }

    private func synchronizeNodes() {
        waveLabel.text = "第 \(engine.level) 关 · \(engine.waveNumber)/\(engine.totalWavesPerLevel) 波"
        bedLevelLabel.text = "床铺 Lv.\(engine.state.bedLevel) · +\(engine.incomePerSecond)/秒"
        doorLevelLabel.text = "Lv.\(engine.state.doorLevel)"
        doorHealthLabel.text = "\(engine.state.doorHealth)"

        let doorRatio = Double(engine.state.doorHealth) / Double(max(1, engine.doorMaxHealth))
        if engine.state.debug.invincibleDoor {
            doorShape.fillColor = UIColor(red: 0.15, green: 0.65, blue: 0.75, alpha: 1)
        } else if doorRatio > 0.5 {
            doorShape.fillColor = UIColor(red: 0.55, green: 0.34, blue: 0.18, alpha: 1)
        } else {
            doorShape.fillColor = UIColor(red: 0.65, green: 0.2, blue: 0.18, alpha: 1)
        }

        for slot in turretNodes.indices {
            if let turret = engine.state.turrets[slot] {
                let color = turretColor(turret.kind)
                turretBases[slot].fillColor = color.withAlphaComponent(0.78)
                turretBases[slot].strokeColor = color
                turretIcons[slot].text = turret.kind.emoji
                turretIcons[slot].fontSize = 19
                turretLevelLabels[slot].text = "Lv.\(turret.level)"
            } else {
                let kind = engine.turretKind(at: slot) ?? .arrow
                turretBases[slot].fillColor = UIColor.white.withAlphaComponent(0.05)
                turretBases[slot].strokeColor = UIColor.white.withAlphaComponent(0.25)
                turretIcons[slot].text = "＋"
                turretIcons[slot].fontSize = 18
                turretLevelLabels[slot].text = kind.displayName
            }
        }

        let enemies = engine.state.enemies
        for index in enemyNodes.indices {
            if index < enemies.count {
                let enemy = enemies[index]
                let color = enemyColor(enemy.kind)
                enemyNodes[index].isHidden = false
                enemyEmojiLabels[index].text = enemy.kind.emoji
                enemyNameLabels[index].text = enemy.kind.displayName
                enemyNameLabels[index].fontColor = color
                let ratio = CGFloat(enemy.health) / CGFloat(max(1, enemy.maxHealth))
                enemyHealthFills[index].xScale = max(0.02, min(1, ratio))
                enemyHealthFills[index].fillColor = color
            } else {
                enemyNodes[index].isHidden = true
            }
        }

        switch engine.state.phase {
        case .playing:
            if engine.remainingEnemies > 0 {
                statusLabel.text = "怪物进攻 · 剩余 \(engine.remainingEnemies) 只"
                statusLabel.fontColor = UIColor(red: 1, green: 0.55, blue: 0.55, alpha: 1)
            } else {
                let seconds = max(0, Int(ceil(engine.state.intermissionRemaining)))
                statusLabel.text = "安全间隙 · \(seconds) 秒"
                statusLabel.fontColor = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1)
            }
        case .lost:
            statusLabel.text = "房门被攻破"
            statusLabel.fontColor = UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        case .ready:
            statusLabel.text = ""
        }
    }

    private func handleEvents(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .shot(let slot):
                fireProjectile(from: slot)
            case .doorHit:
                shakeDoor()
            case .enemyDefeated(let kind):
                if kind == .boss || kind == .brute {
                    showFloatingText("击退 \(kind.displayName)", at: enemyPositions[0])
                }
            case .waveStarted(let level, let wave):
                showWaveBanner("第 \(level) 关 · 第 \(wave) 波")
            case .waveCleared(_, _, let reward):
                showFloatingText("+\(reward) 金币", at: CGPoint(x: 195, y: 258))
            case .levelUp(let level):
                showWaveBanner("进入第 \(level) 关")
            case .lost:
                break
            }
        }
    }

    private func fireProjectile(from slot: Int) {
        guard turretPositions.indices.contains(slot), !engine.state.enemies.isEmpty else { return }
        let target = enemyPositions[0]
        let projectile = SKShapeNode(circleOfRadius: 4.5)
        projectile.position = turretPositions[slot]
        projectile.fillColor = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        projectile.strokeColor = .clear
        projectile.zPosition = 10
        addChild(projectile)
        projectile.run(.sequence([
            .move(to: target, duration: 0.12),
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
        configure(label: label, size: 15, bold: true)
        label.fontColor = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        label.position = position
        label.zPosition = 15
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 45, duration: 0.8), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.45)])]),
            .removeFromParent()
        ]))
    }

    private func showWaveBanner(_ text: String) {
        waveBanner.removeAllActions()
        waveBanner.text = text
        waveBanner.alpha = 0
        waveBanner.run(.sequence([
            .fadeIn(withDuration: 0.15),
            .wait(forDuration: 0.65),
            .fadeOut(withDuration: 0.35)
        ]))
    }

    private func turretColor(_ kind: TurretKind) -> UIColor {
        switch kind {
        case .arrow:
            return UIColor(red: 0.35, green: 0.78, blue: 0.45, alpha: 1)
        case .cannon:
            return UIColor(red: 0.9, green: 0.48, blue: 0.2, alpha: 1)
        case .frost:
            return UIColor(red: 0.35, green: 0.68, blue: 0.98, alpha: 1)
        case .tesla:
            return UIColor(red: 0.78, green: 0.5, blue: 0.95, alpha: 1)
        }
    }

    private func enemyColor(_ kind: EnemyKind) -> UIColor {
        switch kind {
        case .walker:
            return UIColor(red: 0.85, green: 0.9, blue: 1, alpha: 1)
        case .runner:
            return UIColor(red: 0.4, green: 0.9, blue: 0.95, alpha: 1)
        case .brute:
            return UIColor(red: 0.5, green: 0.95, blue: 0.5, alpha: 1)
        case .boss:
            return UIColor(red: 1, green: 0.42, blue: 0.42, alpha: 1)
        }
    }

    private func configure(label: SKLabelNode, size: CGFloat, bold: Bool) {
        label.fontName = bold ? "PingFangSC-Semibold" : "PingFangSC-Regular"
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
    }
}
