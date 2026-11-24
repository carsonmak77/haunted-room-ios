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
    let wavesPerLevel: Int
    let enemySpawnInterval: Double
    let maxUpgradeLevel: Int

    static let standard = GameConfig(
        startingCoins: 80,
        maximumCoins: 1_000_000_000_000_000,
        turretSlotCount: 4,
        intermissionDuration: 4,
        wavesPerLevel: 99_999_999,
        enemySpawnInterval: 0.8,
        maxUpgradeLevel: 99_999_999
    )

    var maxWaves: Int { wavesPerLevel }

    private func growth(_ steps: Int, rate: Double) -> Double {
        let steps = max(0, steps)
        let capped = min(steps, 60)
        let extra = max(0, steps - 60)
        return pow(rate, Double(capped)) * (1 + 0.05 * Double(extra))
    }

    private func boundedInt(_ value: Double, limit: Int = 9_000_000_000_000_000_000) -> Int {
        guard value.isFinite else { return limit }
        let rounded = value.rounded()
        return Int(min(max(0, rounded), Double(limit)))
    }

    private func scaledCost(_ base: Double, rate: Double, level: Int) -> Int {
        let steps = max(0, level - 1)
        let capped = min(steps, 40)
        let extra = max(0, steps - 40)
        let value = base * pow(rate, Double(capped)) * (1 + 0.5 * Double(extra))
        return boundedInt(value, limit: maximumCoins)
    }

    func waveEnemyCount(wave: Int) -> Int {
        min(max(1, wave), 8)
    }

    func enemyKinds(wave: Int) -> [EnemyKind] {
        let count = waveEnemyCount(wave: wave)
        return (0..<count).map { index in
            if wave % 5 == 0 && index == 0 { return .boss }
            if wave >= 3 && (index + wave) % 4 == 0 { return .brute }
            if wave >= 2 && (index + wave) % 2 == 1 { return .runner }
            return .walker
        }
    }

    func enemyHealth(kind: EnemyKind, wave: Int) -> Int {
        boundedInt(Double(kind.baseHealth) * growth(wave - 1, rate: 1.42))
    }

    func enemyDamage(kind: EnemyKind, wave: Int) -> Int {
        boundedInt(
            Double(kind.baseDamage) * growth(wave - 1, rate: 1.18),
            limit: 1_000_000_000_000_000
        )
    }

    func enemyAttackInterval(kind: EnemyKind, wave: Int) -> Double {
        max(0.45, kind.baseAttackInterval - 0.05 * Double(wave - 1))
    }

    func waveReward(wave: Int) -> Int {
        boundedInt(60.0 * growth(wave - 1, rate: 1.45), limit: maximumCoins)
    }

    func bedIncome(bedLevel: Int) -> Int {
        boundedInt(4.0 * Double(bedLevel), limit: maximumCoins)
    }

    func bedUpgradeCost(currentLevel: Int) -> Int {
        scaledCost(80.0, rate: 1.9, level: currentLevel)
    }

    func doorUpgradeCost(currentLevel: Int) -> Int {
        scaledCost(70.0, rate: 1.85, level: currentLevel)
    }

    func turretUpgradeCost(kind: TurretKind, currentLevel: Int) -> Int {
        scaledCost(Double(kind.buildCost), rate: 1.7, level: currentLevel)
    }

    func doorMaxHealth(doorLevel: Int, wave: Int) -> Int {
        let levelFactor = 1.0 + 0.5 * Double(doorLevel - 1)
        return boundedInt(220.0 * levelFactor * growth(wave - 1, rate: 1.35))
    }

    func turretDamage(kind: TurretKind, level: Int, wave: Int) -> Int {
        let levelFactor = 1.0 + 0.6 * Double(level - 1)
        return boundedInt(
            14.0 * levelFactor * kind.damageFactor * growth(wave - 1, rate: 1.3)
        )
    }

    func turretAttackInterval(kind: TurretKind, level: Int) -> Double {
        max(0.3, (1.0 - 0.06 * Double(level - 1)) * kind.intervalFactor)
    }
}

struct GameState: Equatable {
    var phase: GamePhase = .ready
    var coins: Int
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
        doorHealth = config.doorMaxHealth(doorLevel: 1, wave: 1)
        turrets = Array(repeating: nil, count: config.turretSlotCount)
    }
}

enum GameEvent: Equatable {
    case shot(slot: Int)
    case doorHit
    case enemyDefeated(kind: EnemyKind)
    case waveStarted(wave: Int)
    case waveCleared(wave: Int, reward: Int)
    case lost
}
