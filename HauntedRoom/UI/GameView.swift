import SpriteKit
import SwiftUI

struct GameView: View {
    private static let websiteURL = URL(string: "https://520816.xyz")!

    @StateObject private var engine: GameEngine
    @State private var scene: GameScene
    @State private var showAdminPanel = false

    init() {
        let gameEngine = GameEngine()
        _engine = StateObject(wrappedValue: gameEngine)
        _scene = State(initialValue: GameScene(engine: gameEngine))
    }

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.075)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                header
                stats
                waveStatus
                equipmentBar
                SpriteView(scene: scene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .layoutPriority(1)
                roomControls
                turretControls
                footer
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            if engine.state.phase == .ready {
                startOverlay
            } else if engine.state.phase == .lost {
                resultOverlay
            }
        }
        .sheet(isPresented: $showAdminPanel) {
            AdminPanelView(engine: engine)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("守夜小屋")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("第 \(compact(engine.waveNumber)) / \(compact(engine.maxWaves)) 波 · 怪物 Lv.\(compact(engine.monsterLevel))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button(action: { showAdminPanel = true }) {
                Label("管理", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(engine.state.debug.isAdminMode ? .orange : .blue)
            .accessibilityLabel("打开管理员模式")
        }
    }

    private var stats: some View {
        HStack(spacing: 6) {
            statCard(
                title: "波次",
                value: compact(engine.waveNumber),
                icon: "flag.fill",
                color: .mint
            )
            statCard(
                title: "金币",
                value: engine.state.debug.infiniteCoins ? "∞" : compact(engine.state.coins),
                icon: "creditcard.fill",
                color: .yellow
            )
            statCard(
                title: "收益",
                value: "+\(compact(engine.incomePerSecond))",
                icon: "bed.double.fill",
                color: .green
            )
            statCard(
                title: "房门",
                value: compact(engine.state.doorHealth),
                icon: engine.state.debug.invincibleDoor ? "lock.shield.fill" : "shield.fill",
                color: engine.state.debug.invincibleDoor ? .cyan : .orange
            )
        }
    }

    private var waveStatus: some View {
        VStack(spacing: 4) {
            HStack {
                Text("第 \(compact(engine.waveNumber)) 波 · 怪物 Lv.\(compact(engine.monsterLevel))")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(waveStatusText)
                    .font(.caption.monospacedDigit())
            }
            .foregroundColor(.white)

            ProgressView(
                value: Double(engine.waveEnemiesCleared),
                total: Double(max(1, engine.waveEnemyTotal))
            )
            .tint(.red)

            HStack(spacing: 10) {
                ForEach(Array(engine.waveComposition.enumerated()), id: \.offset) { item in
                    Text("\(item.element.kind.emoji)\(item.element.kind.displayName)×\(item.element.count)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .frame(height: 54)
    }

    private var waveStatusText: String {
        guard engine.state.phase == .playing else {
            return engine.state.phase == .lost ? "房门已破" : ""
        }
        if engine.remainingEnemies > 0 {
            return "剩余 \(engine.remainingEnemies) 只"
        }
        let seconds = max(0, Int(ceil(engine.state.intermissionRemaining)))
        return "下一波 \(seconds) 秒"
    }

    private var equipmentBar: some View {
        HStack(spacing: 6) {
            equipmentChip("🛏 Lv.\(compact(engine.state.bedLevel))")
            equipmentChip("🚪 Lv.\(compact(engine.state.doorLevel))")
            equipmentChip("⚔️ DPS \(compact(engine.totalTurretDPS))")
            Spacer(minLength: 0)
        }
    }

    private var roomControls: some View {
        HStack(spacing: 10) {
            controlButton(
                title: "升级床铺 Lv.\(compact(engine.state.bedLevel))",
                subtitle: costText(engine.bedUpgradeCost),
                icon: "bed.double.fill",
                color: .blue,
                disabled: !engine.canUpgradeBed,
                action: { engine.upgradeBed() }
            )
            controlButton(
                title: "升级房门 Lv.\(compact(engine.state.doorLevel))",
                subtitle: costText(engine.doorUpgradeCost),
                icon: "shield.fill",
                color: .orange,
                disabled: !engine.canUpgradeDoor,
                action: { engine.upgradeDoor() }
            )
        }
    }

    private var turretControls: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
            ForEach(engine.state.turrets.indices, id: \.self) { slot in
                let turret = engine.state.turrets[slot]
                let kind = engine.turretKind(at: slot) ?? .arrow
                controlButton(
                    title: turret == nil
                        ? "建造\(kind.displayName) \(slot + 1)"
                        : "\(kind.displayName) \(slot + 1) · Lv.\(compact(turret!.level))",
                    subtitle: costText(engine.turretCost(at: slot)),
                    icon: kind.emoji,
                    isEmoji: true,
                    color: turret == nil ? .purple : .red,
                    disabled: turret == nil ? !engine.canBuildTurret(at: slot) : !engine.canUpgradeTurret(at: slot),
                    action: {
                        if turret == nil {
                            engine.buildTurret(slot: slot)
                        } else {
                            engine.upgradeTurret(slot: slot)
                        }
                    }
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("开发者：CARSON")
                .foregroundColor(.gray)
            Text("·")
                .foregroundColor(.gray.opacity(0.6))
            Link("520816.xyz", destination: Self.websiteURL)
                .foregroundColor(.cyan)
                .accessibilityLabel("访问开发者网站 520816.xyz")
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.bottom, 2)
    }

    private var startOverlay: some View {
        overlayCard(
            title: "夜幕降临",
            subtitle: "共 99,999,999 波，怪物等级从 0 一路涨到 99,999,999。躺床产金币，升级床铺、房门和四类炮塔，炮塔等级无上限。",
            icon: "moon.stars.fill",
            buttonTitle: "躺下开始",
            buttonColor: .blue,
            action: engine.start
        )
    }

    private var resultOverlay: some View {
        overlayCard(
            title: "房门被攻破",
            subtitle: "你守到了第 \(compact(engine.waveNumber)) 波 · 怪物 Lv.\(compact(engine.monsterLevel))。重新发育，再来一次。",
            icon: "door.left.hand.open",
            buttonTitle: "再来一局",
            buttonColor: .red,
            action: engine.restart
        )
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Label(title, systemImage: icon)
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.065))
        .cornerRadius(10)
    }

    private func equipmentChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private func controlButton(
        title: String,
        subtitle: String,
        icon: String,
        isEmoji: Bool = false,
        color: Color,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isEmoji {
                    Text(icon)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: icon)
                        .font(.headline)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(.caption2)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(color.opacity(disabled ? 0.18 : 0.62))
            .cornerRadius(11)
        }
        .disabled(disabled)
    }

    private func overlayCard(
        title: String,
        subtitle: String,
        icon: String,
        buttonTitle: String,
        buttonColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundColor(buttonColor)
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Button(buttonTitle, action: action)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(buttonColor)
                    .cornerRadius(14)
                HStack(spacing: 5) {
                    Text("开发者：CARSON")
                        .foregroundColor(.gray)
                    Text("·")
                        .foregroundColor(.gray.opacity(0.6))
                    Link("520816.xyz", destination: Self.websiteURL)
                        .foregroundColor(.cyan)
                }
                .font(.caption2)
            }
            .padding(26)
            .frame(maxWidth: 340)
            .background(Color(red: 0.09, green: 0.11, blue: 0.18))
            .cornerRadius(24)
            .padding(24)
        }
    }

    private func costText(_ cost: Int?) -> String {
        guard let cost = cost else { return "已满级" }
        return engine.state.debug.infiniteCoins ? "免费 · 管理员" : "\(compact(cost)) 金币"
    }

    private func compact(_ value: Int) -> String {
        let number = Double(max(0, value))
        if value < 10_000 {
            return "\(value)"
        }
        if value < 100_000_000 {
            let scaled = number / 10_000
            return String(format: scaled < 100 ? "%.1f万" : "%.0f万", scaled)
        }
        let scaled = number / 100_000_000
        return String(format: scaled < 100 ? "%.1f亿" : "%.0f亿", scaled)
    }
}
