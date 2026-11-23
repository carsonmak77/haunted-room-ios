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

    var incomePerSecond: Int {
        config.bedIncome[state.bedLevel - 1]
    }

    var doorMaxHealth: Int {
        config.doorMaxHealth[state.doorLevel - 1]
    }

    var waveNumber: Int {
        min(state.waveIndex + 1, config.waves.count)
    }

    var bedUpgradeCost: Int? {
        nextCost(level: state.bedLevel, costs: config.bedUpgradeCosts)
    }

    var doorUpgradeCost: Int? {
        nextCost(level: state.doorLevel, costs: config.doorUpgradeCosts)
    }

    var canUpgradeBed: Bool {
        canAfford(bedUpgradeCost)
    }

    var canUpgradeDoor: Bool {
        canAfford(doorUpgradeCost)
    }

    func turretCost(at slot: Int) -> Int? {
        guard state.turrets.indices.contains(slot) else { return nil }
        guard let turret = state.turrets[slot] else { return config.turretBuildCost }
        return nextCost(level: turret.level, costs: config.turretUpgradeCosts)
    }

    func canBuildTurret(at slot: Int) -> Bool {
        guard state.turrets.indices.contains(slot), state.turrets[slot] == nil else { return false }
        return canAfford(config.turretBuildCost)
    }

    func canUpgradeTurret(at slot: Int) -> Bool {
        guard state.turrets.indices.contains(slot), state.turrets[slot] != nil else { return false }
        return canAfford(turretCost(at: slot))
    }

    func start() {
        guard state.phase == .ready else { return }
        objectWillChange.send()
        state.phase = .playing
        spawnCurrentWave()
    }

    func restart() {
        objectWillChange.send()
        state = GameState(config: config)
        state.phase = .playing
        events.removeAll()
        spawnCurrentWave()
    }

    func advance(dt: Double) {
        guard state.phase == .playing, dt > 0, dt.isFinite else { return }
        objectWillChange.send()
        state.elapsed += dt
        earnIncome(dt: dt)

        for slot in state.turrets.indices {
            guard var turret = state.turrets[slot], state.ghost != nil else { continue }
            turret.cooldown -= dt
            if turret.cooldown <= 0 {
                turret.cooldown = config.turretAttackIntervals[turret.level - 1]
                state.turrets[slot] = turret
                damageGhost(config.turretDamage[turret.level - 1], slot: slot)
            } else {
                state.turrets[slot] = turret
            }
        }

        if state.phase == .playing, state.ghost == nil {
            state.intermissionRemaining -= dt
            if state.intermissionRemaining <= 0 {
                spawnCurrentWave()
            }
        }

        if state.phase == .playing, var ghost = state.ghost {
            ghost.attackCooldown -= dt
            if ghost.attackCooldown <= 0 {
                ghost.attackCooldown = config.waves[state.waveIndex].attackInterval
                state.ghost = ghost
                attackDoor()
            } else {
                state.ghost = ghost
            }
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
        objectWillChange.send()
        guard spend(config.turretBuildCost) else { return false }
        state.turrets[slot] = TurretState(level: 1, cooldown: 0)
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

    func defeatCurrentGhost() {
        guard state.debug.isAdminMode, state.phase == .playing, state.ghost != nil else { return }
        objectWillChange.send()
        handleGhostDefeated()
    }

    func drainEvents() -> [GameEvent] {
        let pending = events
        events.removeAll()
        return pending
    }

    private func nextCost(level: Int, costs: [Int]) -> Int? {
        let index = level - 1
        return costs.indices.contains(index) ? costs[index] : nil
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

    private func spawnCurrentWave() {
        guard config.waves.indices.contains(state.waveIndex) else { return }
        let wave = config.waves[state.waveIndex]
        state.ghost = GhostState(
            health: wave.health,
            maxHealth: wave.health,
            attackCooldown: wave.attackInterval
        )
        state.intermissionRemaining = 0
        events.append(.waveStarted(wave: state.waveIndex + 1))
    }

    private func damageGhost(_ damage: Int, slot: Int) {
        guard var ghost = state.ghost else { return }
        events.append(.shot(slot: slot))
        ghost.health = max(0, ghost.health - damage)
        state.ghost = ghost
        if ghost.health == 0 {
            handleGhostDefeated()
        }
    }

    private func handleGhostDefeated() {
        guard state.ghost != nil else { return }
        let defeatedWave = state.waveIndex
        state.ghost = nil
        addCoins(config.waves[defeatedWave].reward)
        events.append(.ghostDefeated(wave: defeatedWave + 1))

        if defeatedWave == config.waves.count - 1 {
            state.phase = .won
            state.intermissionRemaining = 0
            events.append(.won)
        } else {
            state.waveIndex += 1
            state.intermissionRemaining = config.intermissionDuration
        }
    }

    private func attackDoor() {
        let wave = config.waves[state.waveIndex]
        if !state.debug.invincibleDoor {
            state.doorHealth = max(0, state.doorHealth - wave.damage)
        }
        events.append(.doorHit)
        if state.doorHealth == 0 {
            state.phase = .lost
            events.append(.lost)
        }
    }
}
