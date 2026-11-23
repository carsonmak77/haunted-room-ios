import Foundation

enum GamePhase: Equatable {
    case ready
    case playing
    case won
    case lost
}

struct DebugOptions: Equatable {
    var isAdminMode = false
    var infiniteCoins = false
    var invincibleDoor = false
    var speedMultiplier: Double = 1
}

struct TurretState: Equatable {
    var level: Int
    var cooldown: Double
}

struct GhostState: Equatable {
    var health: Int
    let maxHealth: Int
    var attackCooldown: Double
}

struct WaveConfig: Equatable {
    let health: Int
    let damage: Int
    let attackInterval: Double
    let reward: Int
}

struct GameConfig {
    let startingCoins: Int
    let maximumCoins: Int
    let turretSlotCount: Int
    let intermissionDuration: Double
    let bedIncome: [Int]
    let bedUpgradeCosts: [Int]
    let doorMaxHealth: [Int]
    let doorUpgradeCosts: [Int]
    let turretBuildCost: Int
    let turretUpgradeCosts: [Int]
    let turretDamage: [Int]
    let turretAttackIntervals: [Double]
    let waves: [WaveConfig]

    static let standard = GameConfig(
        startingCoins: 80,
        maximumCoins: 9_999_999,
        turretSlotCount: 4,
        intermissionDuration: 5,
        bedIncome: [4, 8, 16, 28, 45],
        bedUpgradeCosts: [80, 160, 300, 500],
        doorMaxHealth: [220, 340, 520, 760, 1_100],
        doorUpgradeCosts: [70, 150, 280, 450],
        turretBuildCost: 50,
        turretUpgradeCosts: [80, 150, 260],
        turretDamage: [14, 26, 45, 72],
        turretAttackIntervals: [1.0, 0.9, 0.8, 0.65],
        waves: [
            WaveConfig(health: 180, damage: 8, attackInterval: 1.5, reward: 60),
            WaveConfig(health: 360, damage: 12, attackInterval: 1.4, reward: 90),
            WaveConfig(health: 650, damage: 18, attackInterval: 1.3, reward: 130),
            WaveConfig(health: 1_000, damage: 24, attackInterval: 1.15, reward: 180),
            WaveConfig(health: 1_600, damage: 32, attackInterval: 1.0, reward: 300)
        ]
    )
}

struct GameState: Equatable {
    var phase: GamePhase = .ready
    var coins: Int
    var bedLevel = 1
    var doorLevel = 1
    var doorHealth: Int
    var waveIndex = 0
    var turrets: [TurretState?]
    var ghost: GhostState?
    var intermissionRemaining: Double = 0
    var elapsed: Double = 0
    var incomeRemainder: Double = 0
    var debug = DebugOptions()

    init(config: GameConfig) {
        coins = config.startingCoins
        doorHealth = config.doorMaxHealth[0]
        turrets = Array(repeating: nil, count: config.turretSlotCount)
    }
}

enum GameEvent: Equatable {
    case shot(slot: Int)
    case doorHit
    case ghostDefeated(wave: Int)
    case waveStarted(wave: Int)
    case won
    case lost
}
