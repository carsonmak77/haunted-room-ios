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

            VStack(spacing: 10) {
                header
                stats
                ghostStatus
                SpriteView(scene: scene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .layoutPriority(1)
                roomControls
                turretControls
                footer
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if engine.state.phase == .ready {
                startOverlay
            } else if engine.state.phase == .won || engine.state.phase == .lost {
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
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("躺好发育，守住最后一道门")
                    .font(.caption)
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
        HStack(spacing: 8) {
            statCard(
                title: "金币",
                value: engine.state.debug.infiniteCoins ? "∞" : "\(engine.state.coins)",
                icon: "creditcard.fill",
                color: .yellow
            )
            statCard(
                title: "每秒收益",
                value: "+\(engine.incomePerSecond)",
                icon: "bed.double.fill",
                color: .green
            )
            statCard(
                title: "房门耐久",
                value: "\(engine.state.doorHealth)",
                icon: engine.state.debug.invincibleDoor ? "lock.shield.fill" : "shield.fill",
                color: engine.state.debug.invincibleDoor ? .cyan : .orange
            )
        }
    }

    private var ghostStatus: some View {
        VStack(spacing: 5) {
            if let ghost = engine.state.ghost {
                HStack {
                    Text("第 \(engine.waveNumber) 波猛鬼")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(ghost.health) / \(ghost.maxHealth)")
                        .font(.caption.monospacedDigit())
                }
                .foregroundColor(.white)
                ProgressView(value: Double(ghost.health), total: Double(ghost.maxHealth))
                    .tint(.red)
            } else {
                Text(engine.state.phase == .playing ? "下一波正在赶来…" : "准备进入小屋")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 36)
    }

    private var roomControls: some View {
        HStack(spacing: 10) {
            controlButton(
                title: "升级床铺 · Lv.\(engine.state.bedLevel)",
                subtitle: costText(engine.bedUpgradeCost),
                icon: "bed.double.fill",
                color: .blue,
                disabled: !engine.canUpgradeBed,
                action: { engine.upgradeBed() }
            )
            controlButton(
                title: "升级房门 · Lv.\(engine.state.doorLevel)",
                subtitle: costText(engine.doorUpgradeCost),
                icon: "shield.fill",
                color: .orange,
                disabled: !engine.canUpgradeDoor,
                action: { engine.upgradeDoor() }
            )
        }
    }

    private var turretControls: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(engine.state.turrets.indices, id: \.self) { slot in
                let turret = engine.state.turrets[slot]
                controlButton(
                    title: turret == nil ? "建造炮台 \(slot + 1)" : "炮台 \(slot + 1) · Lv.\(turret!.level)",
                    subtitle: costText(engine.turretCost(at: slot)),
                    icon: turret == nil ? "plus.circle.fill" : "bolt.circle.fill",
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
            subtitle: "躺在床上持续获得金币，升级防御并击退 5 波猛鬼。",
            icon: "moon.stars.fill",
            buttonTitle: "躺下开始",
            buttonColor: .blue,
            action: engine.start
        )
    }

    private var resultOverlay: some View {
        let won = engine.state.phase == .won
        return overlayCard(
            title: won ? "守夜成功" : "房门被攻破",
            subtitle: won ? "所有猛鬼都被击退，小屋迎来了黎明。" : "调整发育和防御节奏，再守一次夜。",
            icon: won ? "sun.max.fill" : "door.left.hand.open",
            buttonTitle: "再来一局",
            buttonColor: won ? .green : .red,
            action: engine.restart
        )
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.065))
        .cornerRadius(12)
    }

    private func controlButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(subtitle)
                        .font(.caption2)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
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
            VStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 56))
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
            .padding(28)
            .frame(maxWidth: 340)
            .background(Color(red: 0.09, green: 0.11, blue: 0.18))
            .cornerRadius(24)
            .padding(24)
        }
    }

    private func costText(_ cost: Int?) -> String {
        guard let cost = cost else { return "已满级" }
        return engine.state.debug.infiniteCoins ? "免费 · 管理员" : "\(cost) 金币"
    }
}
