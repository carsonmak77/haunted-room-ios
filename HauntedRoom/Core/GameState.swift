import Foundation

enum GamePhase: Equatable {
    case ready
    case playing
    case lost
}

struct DebugOptions: Equatable {
    var isAdminMode = false
    var infiniteCoins = false
    var invincibleDoor = false
    var speedMultiplier: Double = 1
}

enum EnemyKind: String, CaseIterable, Equatable {
    case walker
    case runner
    case brute
    case boss

    var displayName: String {
        switch self {
        case .walker: return "游魂"
        case .runner: return "疾行鬼"
        case .brute: return "壮鬼"
        case .boss: return "鬼王"
        }
    }

    var emoji: String {
        switch self {
        case .walker: return "👻"
        case .runner: return "💀"
        case .brute: return "🧟"
        case .boss: return "👹"
        }
    }

    var baseHealth: Int {
        switch self {
        case .walker: return 150
        case .runner: return 95
        case .brute: return 420
        case .boss: return 1_100
        }
    }

    var baseDamage: Int {
        switch self {
        case .walker: return 8
        case .runner: return 6
        case .brute: return 16
        case .boss: return 30
        }
    }

    var baseAttackInterval: Double {
        switch self {
        case .walker: return 1.5
        case .runner: return 0.95
        case .brute: return 1.9
        case .boss: return 1.7
        }
    }
}

enum TurretKind: String, CaseIterable, Equatable {
    case arrow
    case cannon
    case frost
    case tesla

    var displayName: String {
        switch self {
        case .arrow: return "箭塔"
        case .cannon: return "炮塔"
        case .frost: return "冰塔"
        case .tesla: return "雷塔"
        }
    }

    var emoji: String {
        switch self {
        case .arrow: return "🏹"
        case .cannon: return "💣"
        case .frost: return "❄️"
        case .tesla: return "⚡️"
        }
    }

    var damageFactor: Double {
        switch self {
        case .arrow: return 1.0
        case .cannon: return 2.0
        case .frost: return 0.8
        case .tesla: return 1.5
        }
    }

    var intervalFactor: Double {
        switch self {
        case .arrow: return 1.0
        case .cannon: return 1.5
        case .frost: return 1.1
        case .tesla: return 1.2
        }
    }

    var buildCost: Int {
        switch self {
        case .arrow: return 50
        case .cannon: return 70
        case .frost: return 60
        case .tesla: return 90
        }
    }
}

struct TurretState: Equatable {
    var kind: TurretKind
    var level: Int
    var cooldown: Double
}

struct EnemyState: Identifiable, Equatable {
    let id: Int
    var kind: EnemyKind
    var health: Int
    let maxHealth: Int
    var attackCooldown: Double
}

struct GameConfig {
    let startingCoins: Int
    let maximumCoins: Int
    let turretSlotCount: Int
    let intermissionDuration: Double
    let levelUpDuration: Double
    let wavesPerLevel: Int
    let enemySpawnInterval: Double

    static let standard = GameConfig(
        startingCoins: 80,
        maximumCoins: 9_999_999,
        turretSlotCount: 4,
        intermissionDuration: 4,
        levelUpDuration: 6,
        wavesPerLevel: 5,
        enemySpawnInterval: 0.8
    )

    func waveEnemyCount(level: Int, wave: Int) -> Int {
        min(max(1, wave + (level - 1) / 2), 8)
    }

    func enemyKinds(level: Int, wave: Int) -> [EnemyKind] {
        let count = waveEnemyCount(level: level, wave: wave)
        return (0..<count).map { index in
            if wave == wavesPerLevel && index == 0 { return .boss }
            if level >= 2 && (index + wave) % 4 == 0 { return .brute }
            if wave >= 2 && (index + wave) % 2 == 1 { return .runner }
            return .walker
        }
    }

    func enemyHealth(kind: EnemyKind, level: Int, wave: Int) -> Int {
        let value = Double(kind.baseHealth)
            * pow(1.42, Double(wave - 1))
            * pow(1.38, Double(level - 1))
        return max(1, Int(value.rounded()))
    }

    func enemyDamage(kind: EnemyKind, level: Int, wave: Int) -> Int {
        let value = Double(kind.baseDamage)
            * pow(1.18, Double(wave - 1))
            * pow(1.13, Double(level - 1))
        return max(1, Int(value.rounded()))
    }

    func enemyAttackInterval(kind: EnemyKind, level: Int, wave: Int) -> Double {
        max(0.45, kind.baseAttackInterval - 0.05 * Double(wave - 1) - 0.02 * Double(level - 1))
    }

    func waveReward(level: Int, wave: Int) -> Int {
        let value = 60.0 * pow(1.45, Double(wave - 1)) * pow(1.3, Double(level - 1))
        return max(1, Int(value.rounded()))
    }

    func bedIncome(bedLevel: Int, level: Int) -> Int {
        4 * bedLevel * level
    }

    func maxBedLevel(level: Int) -> Int {
        min(3 + level, 12)
    }

    func maxDoorLevel(level: Int) -> Int {
        min(3 + level, 12)
    }

    func maxTurretLevel(level: Int) -> Int {
        min(3 + level, 12)
    }

    func bedUpgradeCost(currentLevel: Int) -> Int {
        Int((80.0 * pow(1.9, Double(currentLevel - 1))).rounded())
    }

    func doorUpgradeCost(currentLevel: Int) -> Int {
        Int((70.0 * pow(1.85, Double(currentLevel - 1))).rounded())
    }

    func turretUpgradeCost(kind: TurretKind, currentLevel: Int) -> Int {
        let base = 80.0 * pow(1.8, Double(currentLevel - 1))
        let kindFactor = Double(kind.buildCost) / 50.0
        return Int((base * kindFactor).rounded())
    }

    func doorMaxHealth(doorLevel: Int, level: Int) -> Int {
        let value = 220.0 * pow(1.55, Double(doorLevel - 1)) * pow(1.3, Double(level - 1))
        return max(1, Int(value.rounded()))
    }

    func turretDamage(kind: TurretKind, level: Int, playerLevel: Int) -> Int {
        let value = 14.0
            * (1.0 + 0.6 * Double(level - 1))
            * kind.damageFactor
            * pow(1.22, Double(playerLevel - 1))
        return max(1, Int(value.rounded()))
    }

    func turretAttackInterval(kind: TurretKind, level: Int) -> Double {
        max(0.3, (1.0 - 0.06 * Double(level - 1)) * kind.intervalFactor)
    }
}

struct GameState: Equatable {
    var phase: GamePhase = .ready
    var coins: Int
    var level = 1
    var waveIndex = 0
    var bedLevel = 1
    var doorLevel = 1
    var doorHealth: Int
    var turrets: [TurretState?]
    var enemies: [EnemyState] = []
    var nextEnemyID = 0
    var waveKinds: [EnemyKind] = []
    var enemiesRemainingToSpawn = 0
    var spawnCooldown: Double = 0
    var intermissionRemaining: Double = 0
    var elapsed: Double = 0
    var incomeRemainder: Double = 0
    var debug = DebugOptions()

    init(config: GameConfig) {
        coins = config.startingCoins
        doorHealth = config.doorMaxHealth(doorLevel: 1, level: 1)
        turrets = Array(repeating: nil, count: config.turretSlotCount)
    }
}

enum GameEvent: Equatable {
    case shot(slot: Int)
    case doorHit
    case enemyDefeated(kind: EnemyKind)
    case waveStarted(level: Int, wave: Int)
    case waveCleared(level: Int, wave: Int, reward: Int)
    case levelUp(Int)
    case lost
}
