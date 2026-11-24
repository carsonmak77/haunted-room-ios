import Combine
import Foundation

final class GameEngine: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let config: GameConfig
    private(set) var state: GameState
    private var events: [GameEvent] = []

    init(config: GameConfig = .standard) {
        self.config = config
        state = GameState(config: config)
    }

    var level: Int { state.level }
    var waveNumber: Int { state.waveIndex + 1 }
    var totalWavesPerLevel: Int { config.wavesPerLevel }
    var incomePerSecond: Int { config.bedIncome(bedLevel: state.bedLevel, level: state.level) }
    var doorMaxHealth: Int { config.doorMaxHealth(doorLevel: state.doorLevel, level: state.level) }
    var maxBedLevel: Int { config.maxBedLevel(level: state.level) }
    var maxDoorLevel: Int { config.maxDoorLevel(level: state.level) }
    var maxTurretLevel: Int { config.maxTurretLevel(level: state.level) }

    var remainingEnemies: Int { state.enemies.count + state.enemiesRemainingToSpawn }
    var waveEnemyTotal: Int { state.waveKinds.count }
    var waveEnemiesCleared: Int { max(0, state.waveKinds.count - remainingEnemies) }

    var waveComposition: [(kind: EnemyKind, count: Int)] {
        EnemyKind.allCases.compactMap { kind in
            let count = state.waveKinds.filter { $0 == kind }.count
            return count > 0 ? (kind: kind, count: count) : nil
        }
    }

    var totalTurretDPS: Int {
        state.turrets.indices.reduce(0) { total, slot in
            guard let turret = state.turrets[slot] else { return total }
            let damage = Double(config.turretDamage(kind: turret.kind, level: turret.level, playerLevel: state.level))
            let interval = config.turretAttackInterval(kind: turret.kind, level: turret.level)
            return total + Int((damage / interval).rounded())
        }
    }

    var bedUpgradeCost: Int? {
        guard state.bedLevel < maxBedLevel else { return nil }
        return config.bedUpgradeCost(currentLevel: state.bedLevel)
    }

    var doorUpgradeCost: Int? {
        guard state.doorLevel < maxDoorLevel else { return nil }
        return config.doorUpgradeCost(currentLevel: state.doorLevel)
    }

    var canUpgradeBed: Bool { canAfford(bedUpgradeCost) }
    var canUpgradeDoor: Bool { canAfford(doorUpgradeCost) }

    func turretKind(at slot: Int) -> TurretKind? {
        guard state.turrets.indices.contains(slot) else { return nil }
        if let turret = state.turrets[slot] { return turret.kind }
        return TurretKind.allCases[slot % TurretKind.allCases.count]
    }

    func turretCost(at slot: Int) -> Int? {
        guard let kind = turretKind(at: slot) else { return nil }
        guard let turret = state.turrets[slot] else { return kind.buildCost }
        guard turret.level < maxTurretLevel else { return nil }
        return config.turretUpgradeCost(kind: turret.kind, currentLevel: turret.level)
    }

    func turretDamage(at slot: Int) -> Int {
        guard let turret = state.turrets[slot] else { return 0 }
        return config.turretDamage(kind: turret.kind, level: turret.level, playerLevel: state.level)
    }

    func canBuildTurret(at slot: Int) -> Bool {
        guard state.turrets.indices.contains(slot), state.turrets[slot] == nil else { return false }
        guard let cost = turretCost(at: slot) else { return false }
        return canAfford(cost)
    }

    func canUpgradeTurret(at slot: Int) -> Bool {
        guard state.turrets.indices.contains(slot), state.turrets[slot] != nil else { return false }
        return canAfford(turretCost(at: slot))
    }

    func start() {
        guard state.phase == .ready else { return }
        objectWillChange.send()
        state.phase = .playing
        beginWave()
    }

    func restart() {
        objectWillChange.send()
        state = GameState(config: config)
        state.phase = .playing
        events.removeAll()
        beginWave()
    }

    func advance(dt: Double) {
        guard state.phase == .playing, dt > 0, dt.isFinite else { return }
        objectWillChange.send()
        let waitingForNextWave = isWaitingForNextWave
        state.elapsed += dt
        earnIncome(dt: dt)
        updateSpawning(dt: dt)
        updateTurrets(dt: dt)
        updateEnemyAttacks(dt: dt)
        checkWaveCleared()

        guard waitingForNextWave, state.phase == .playing else { return }
        state.intermissionRemaining = max(0, state.intermissionRemaining - dt)
        if state.intermissionRemaining == 0 {
            beginWave()
        }
    }

    @discardableResult
    func upgradeBed() -> Bool {
        guard state.phase == .playing, let cost = bedUpgradeCost, canAfford(cost) else { return false }
        objectWillChange.send()
        guard spend(cost) else { return false }
        state.bedLevel += 1
        return true
    }

    @discardableResult
    func upgradeDoor() -> Bool {
        guard state.phase == .playing, let cost = doorUpgradeCost, canAfford(cost) else { return false }
        objectWillChange.send()
        guard spend(cost) else { return false }
        state.doorLevel += 1
        state.doorHealth = doorMaxHealth
        return true
    }

    @discardableResult
    func buildTurret(slot: Int) -> Bool {
        guard state.phase == .playing, canBuildTurret(at: slot) else { return false }
        guard let kind = turretKind(at: slot), let cost = turretCost(at: slot) else { return false }
        objectWillChange.send()
        guard spend(cost) else { return false }
        state.turrets[slot] = TurretState(kind: kind, level: 1, cooldown: 0)
        return true
    }

    @discardableResult
    func upgradeTurret(slot: Int) -> Bool {
        guard state.phase == .playing, canUpgradeTurret(at: slot), let cost = turretCost(at: slot) else { return false }
        objectWillChange.send()
        guard spend(cost) else { return false }
        state.turrets[slot]?.level += 1
        return true
    }

    func setAdminMode(_ enabled: Bool) {
        objectWillChange.send()
        state.debug.isAdminMode = enabled
        if !enabled {
            state.debug.infiniteCoins = false
            state.debug.invincibleDoor = false
            state.debug.speedMultiplier = 1
        }
    }

    func setInfiniteCoins(_ enabled: Bool) {
        guard state.debug.isAdminMode else { return }
        objectWillChange.send()
        state.debug.infiniteCoins = enabled
    }

    func setInvincibleDoor(_ enabled: Bool) {
        guard state.debug.isAdminMode else { return }
        objectWillChange.send()
        state.debug.invincibleDoor = enabled
    }

    func setSpeed(_ multiplier: Double) {
        guard state.debug.isAdminMode, [1, 2, 4].contains(multiplier) else { return }
        objectWillChange.send()
        state.debug.speedMultiplier = multiplier
    }

    func addDebugCoins() {
        guard state.debug.isAdminMode, state.phase == .playing else { return }
        objectWillChange.send()
        addCoins(1_000)
    }

    func defeatCurrentWave() {
        guard state.debug.isAdminMode, state.phase == .playing, !state.enemies.isEmpty || state.enemiesRemainingToSpawn > 0 else { return }
        objectWillChange.send()
        state.enemies.removeAll()
        state.enemiesRemainingToSpawn = 0
        checkWaveCleared()
    }

    func drainEvents() -> [GameEvent] {
        let pending = events
        events.removeAll()
        return pending
    }

    private var isWaitingForNextWave: Bool {
        state.enemies.isEmpty
            && state.enemiesRemainingToSpawn == 0
            && state.intermissionRemaining > 0
    }

    private func canAfford(_ cost: Int?) -> Bool {
        guard state.phase == .playing, let cost = cost else { return false }
        return state.debug.infiniteCoins || state.coins >= cost
    }

    private func spend(_ cost: Int) -> Bool {
        if state.debug.infiniteCoins { return true }
        guard state.coins >= cost else { return false }
        state.coins -= cost
        return true
    }

    private func earnIncome(dt: Double) {
        state.incomeRemainder += Double(incomePerSecond) * dt
        let earned = Int(state.incomeRemainder)
        guard earned > 0 else { return }
        state.incomeRemainder -= Double(earned)
        addCoins(earned)
    }

    private func addCoins(_ amount: Int) {
        let result = state.coins.addingReportingOverflow(amount)
        state.coins = result.overflow ? config.maximumCoins : min(result.partialValue, config.maximumCoins)
    }

    private func beginWave() {
        let kinds = config.enemyKinds(level: state.level, wave: waveNumber)
        state.waveKinds = kinds
        state.enemies.removeAll()
        state.enemiesRemainingToSpawn = kinds.count
        state.spawnCooldown = 0
        state.intermissionRemaining = 0
        events.append(.waveStarted(level: state.level, wave: waveNumber))
        updateSpawning(dt: 0)
    }

    private func updateSpawning(dt: Double) {
        guard state.enemiesRemainingToSpawn > 0 else { return }
        state.spawnCooldown -= dt
        var spawned = 0
        while state.spawnCooldown <= 0, state.enemiesRemainingToSpawn > 0, spawned < 16 {
            spawnEnemy()
            spawned += 1
        }
    }

    private func spawnEnemy() {
        guard state.enemiesRemainingToSpawn > 0 else { return }
        let index = state.waveKinds.count - state.enemiesRemainingToSpawn
        guard state.waveKinds.indices.contains(index) else { return }
        let kind = state.waveKinds[index]
        state.enemiesRemainingToSpawn -= 1
        state.spawnCooldown += config.enemySpawnInterval

        let health = config.enemyHealth(kind: kind, level: state.level, wave: waveNumber)
        let enemy = EnemyState(
            id: state.nextEnemyID,
            kind: kind,
            health: health,
            maxHealth: health,
            attackCooldown: config.enemyAttackInterval(kind: kind, level: state.level, wave: waveNumber)
        )
        state.nextEnemyID += 1
        state.enemies.append(enemy)
    }

    private func updateTurrets(dt: Double) {
        for slot in state.turrets.indices {
            guard var turret = state.turrets[slot] else { continue }
            guard !state.enemies.isEmpty else {
                turret.cooldown = max(0, turret.cooldown - dt)
                state.turrets[slot] = turret
                continue
            }

            turret.cooldown -= dt
            var shots = 0
            while turret.cooldown <= 0, !state.enemies.isEmpty, shots < 16 {
                turret.cooldown += config.turretAttackInterval(kind: turret.kind, level: turret.level)
                fire(slot: slot, damage: config.turretDamage(kind: turret.kind, level: turret.level, playerLevel: state.level))
                shots += 1
            }
            state.turrets[slot] = turret
        }
    }

    private func fire(slot: Int, damage: Int) {
        guard !state.enemies.isEmpty else { return }
        events.append(.shot(slot: slot))
        var enemy = state.enemies[0]
        enemy.health = max(0, enemy.health - damage)
        if enemy.health == 0 {
            state.enemies.removeFirst()
            events.append(.enemyDefeated(kind: enemy.kind))
        } else {
            state.enemies[0] = enemy
        }
    }

    private func updateEnemyAttacks(dt: Double) {
        guard state.phase == .playing, !state.enemies.isEmpty else { return }
        var enemy = state.enemies[0]
        enemy.attackCooldown -= dt
        var attacks = 0
        while enemy.attackCooldown <= 0, state.phase == .playing, attacks < 16 {
            enemy.attackCooldown += config.enemyAttackInterval(kind: enemy.kind, level: state.level, wave: waveNumber)
            applyDoorDamage(config.enemyDamage(kind: enemy.kind, level: state.level, wave: waveNumber))
            attacks += 1
        }
        if !state.enemies.isEmpty {
            state.enemies[0] = enemy
        }
    }

    private func applyDoorDamage(_ damage: Int) {
        if !state.debug.invincibleDoor {
            state.doorHealth = max(0, state.doorHealth - damage)
        }
        events.append(.doorHit)
        if state.doorHealth == 0 {
            state.phase = .lost
            events.append(.lost)
        }
    }

    private func checkWaveCleared() {
        guard state.phase == .playing,
              state.enemies.isEmpty,
              state.enemiesRemainingToSpawn == 0,
              state.intermissionRemaining == 0,
              !state.waveKinds.isEmpty else { return }

        let clearedLevel = state.level
        let clearedWave = waveNumber
        let reward = config.waveReward(level: clearedLevel, wave: clearedWave)
        addCoins(reward)
        events.append(.waveCleared(level: clearedLevel, wave: clearedWave, reward: reward))

        if clearedWave >= config.wavesPerLevel {
            state.level += 1
            state.waveIndex = 0
            let healed = state.doorHealth + doorMaxHealth / 4
            state.doorHealth = min(doorMaxHealth, healed)
            state.intermissionRemaining = config.levelUpDuration
            events.append(.levelUp(state.level))
        } else {
            state.waveIndex += 1
            state.intermissionRemaining = config.intermissionDuration
        }
    }
}
