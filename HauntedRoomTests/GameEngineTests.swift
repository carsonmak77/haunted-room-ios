import XCTest
@testable import HauntedRoom

final class GameEngineTests: XCTestCase {
    func testIncomeTicksOnlyWhilePlaying() {
        let engine = GameEngine()
        XCTAssertEqual(engine.state.phase, .ready)

        engine.advance(dt: 3)
        XCTAssertEqual(engine.state.coins, engine.config.startingCoins)

        engine.start()
        engine.advance(dt: 1)
        XCTAssertEqual(engine.state.coins, engine.config.startingCoins + engine.incomePerSecond)
    }

    func testBedUpgradeCostAndIncome() {
        let engine = GameEngine()
        engine.start()

        XCTAssertEqual(engine.bedUpgradeCost, 80)
        XCTAssertTrue(engine.upgradeBed())
        XCTAssertEqual(engine.state.coins, 0)
        XCTAssertEqual(engine.incomePerSecond, 8)
        XCTAssertFalse(engine.upgradeBed())
        XCTAssertEqual(engine.bedUpgradeCost, 152)
    }

    func testInvalidPurchasesAreRejected() {
        let engine = GameEngine()
        engine.start()

        XCTAssertTrue(engine.buildTurret(slot: 0))
        XCTAssertEqual(engine.state.coins, 30)
        XCTAssertFalse(engine.buildTurret(slot: 1))
        XCTAssertFalse(engine.buildTurret(slot: 99))
        XCTAssertFalse(engine.buildTurret(slot: 0))
        XCTAssertFalse(engine.upgradeDoor())
    }

    func testDoorUpgradeRestoresDurability() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.setInfiniteCoins(true)

        engine.advance(dt: 1.5)
        XCTAssertEqual(engine.state.doorHealth, 212)

        XCTAssertTrue(engine.upgradeDoor())
        XCTAssertEqual(engine.state.doorLevel, 2)
        XCTAssertEqual(engine.state.doorHealth, 341)
    }

    func testTurretDamagesFrontEnemyAndDoorTakesHit() {
        let engine = GameEngine()
        engine.start()
        XCTAssertTrue(engine.buildTurret(slot: 0))

        engine.advance(dt: 0.1)
        XCTAssertEqual(engine.state.enemies.first?.health, 136)
        XCTAssertEqual(engine.state.doorHealth, 220)

        engine.advance(dt: 1.4)
        XCTAssertEqual(engine.state.enemies.first?.health, 122)
        XCTAssertEqual(engine.state.doorHealth, 212)
    }

    func testWaveClearRewardsAndAdvances() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)

        engine.defeatCurrentWave()
        XCTAssertEqual(engine.state.coins, 140)
        XCTAssertEqual(engine.waveNumber, 2)
        XCTAssertEqual(engine.state.intermissionRemaining, 4, accuracy: 0.001)

        engine.advance(dt: 4)
        XCTAssertEqual(engine.waveNumber, 2)
        XCTAssertEqual(engine.state.enemies.count, 1)
        XCTAssertEqual(engine.state.enemies.first?.kind, .walker)
        XCTAssertEqual(engine.state.enemies.first?.maxHealth, 213)
    }

    func testFiveWavesLevelUpAndScale() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)

        for wave in 1...5 {
            XCTAssertEqual(engine.waveNumber, wave)
            engine.defeatCurrentWave()
            if wave < 5 {
                engine.advance(dt: 4)
            }
        }

        XCTAssertEqual(engine.level, 2)
        XCTAssertEqual(engine.state.phase, .playing)
        XCTAssertEqual(engine.state.intermissionRemaining, 6, accuracy: 0.001)

        engine.advance(dt: 6)
        XCTAssertEqual(engine.waveNumber, 1)
        XCTAssertEqual(engine.state.enemies.first?.kind, .walker)
        XCTAssertEqual(engine.state.enemies.first?.maxHealth, 207)
    }

    func testEndlessLevelsKeepGoing() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)

        for _ in 0..<10 {
            engine.defeatCurrentWave()
            let wait = engine.state.intermissionRemaining
            if wait > 0 {
                engine.advance(dt: wait)
            }
        }

        XCTAssertEqual(engine.level, 3)
        XCTAssertEqual(engine.state.phase, .playing)
        XCTAssertEqual(engine.waveNumber, 1)
    }

    func testDoorBreakLosesRun() {
        let engine = GameEngine()
        engine.start()

        for _ in 0..<28 {
            engine.advance(dt: 1.5)
        }

        XCTAssertEqual(engine.state.phase, .lost)
        XCTAssertEqual(engine.state.doorHealth, 0)
    }

    func testInfiniteCoinsIgnoreCostsAndLevelCaps() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.setInfiniteCoins(true)

        for slot in 0..<engine.config.turretSlotCount {
            XCTAssertTrue(engine.buildTurret(slot: slot))
        }
        for slot in 0..<engine.config.turretSlotCount {
            while engine.turretCost(at: slot) != nil {
                XCTAssertTrue(engine.upgradeTurret(slot: slot))
            }
            XCTAssertEqual(engine.state.turrets[slot]?.level, engine.maxTurretLevel)
        }

        XCTAssertEqual(engine.state.coins, engine.config.startingCoins)
    }

    func testInvincibleDoorStopsDamage() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.setInvincibleDoor(true)

        for _ in 0..<20 {
            engine.advance(dt: 1.5)
        }

        XCTAssertEqual(engine.state.phase, .playing)
        XCTAssertEqual(engine.state.doorHealth, 220)
    }

    func testAdminActionsRequireAdminMode() {
        let engine = GameEngine()
        engine.start()

        engine.setInfiniteCoins(true)
        engine.setInvincibleDoor(true)
        engine.defeatCurrentWave()

        XCTAssertFalse(engine.state.debug.infiniteCoins)
        XCTAssertFalse(engine.state.debug.invincibleDoor)
        XCTAssertEqual(engine.state.enemies.count, 1)
        XCTAssertEqual(engine.state.coins, engine.config.startingCoins)
    }

    func testDisablingAdminResetsDebugOptions() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.setInfiniteCoins(true)
        engine.setInvincibleDoor(true)
        engine.setSpeed(4)

        engine.setAdminMode(false)

        XCTAssertFalse(engine.state.debug.isAdminMode)
        XCTAssertFalse(engine.state.debug.infiniteCoins)
        XCTAssertFalse(engine.state.debug.invincibleDoor)
        XCTAssertEqual(engine.state.debug.speedMultiplier, 1)
    }

    func testSpeedValidation() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)

        engine.setSpeed(3)
        XCTAssertEqual(engine.state.debug.speedMultiplier, 1)

        engine.setSpeed(4)
        XCTAssertEqual(engine.state.debug.speedMultiplier, 4)
    }

    func testRestartResetsRun() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.addDebugCoins()
        XCTAssertTrue(engine.upgradeBed())

        engine.restart()

        XCTAssertEqual(engine.state.phase, .playing)
        XCTAssertEqual(engine.state.coins, engine.config.startingCoins)
        XCTAssertEqual(engine.state.level, 1)
        XCTAssertEqual(engine.waveNumber, 1)
        XCTAssertEqual(engine.state.bedLevel, 1)
        XCTAssertEqual(engine.state.doorLevel, 1)
        XCTAssertEqual(engine.state.doorHealth, 220)
        XCTAssertEqual(engine.state.enemies.count, 1)
        XCTAssertEqual(engine.state.enemies.first?.health, 150)
        XCTAssertFalse(engine.state.debug.isAdminMode)
        XCTAssertTrue(engine.state.turrets.allSatisfy { $0 == nil })
    }

    func testInvalidDeltaIsIgnored() {
        let engine = GameEngine()
        engine.start()

        engine.advance(dt: 0)
        engine.advance(dt: -1)
        engine.advance(dt: .nan)
        engine.advance(dt: .infinity)

        XCTAssertEqual(engine.state.elapsed, 0)
        XCTAssertEqual(engine.state.coins, engine.config.startingCoins)
        XCTAssertEqual(engine.state.enemies.first?.health, 150)
    }

    func testEventsAreEmittedOnce() {
        let engine = GameEngine()
        engine.start()

        XCTAssertEqual(engine.drainEvents(), [.waveStarted(level: 1, wave: 1)])
        XCTAssertTrue(engine.drainEvents().isEmpty)
    }

    func testWaveDifficultyScales() {
        let config = GameConfig.standard

        XCTAssertEqual(config.waveEnemyCount(level: 1, wave: 1), 1)
        XCTAssertEqual(config.waveEnemyCount(level: 1, wave: 5), 5)
        XCTAssertEqual(config.waveEnemyCount(level: 3, wave: 5), 6)
        XCTAssertEqual(config.enemyKinds(level: 1, wave: 5).first, .boss)
        XCTAssertGreaterThan(
            config.enemyHealth(kind: .walker, level: 2, wave: 1),
            config.enemyHealth(kind: .walker, level: 1, wave: 1)
        )
        XCTAssertGreaterThan(
            config.enemyDamage(kind: .walker, level: 2, wave: 1),
            config.enemyDamage(kind: .walker, level: 1, wave: 1)
        )
        XCTAssertGreaterThan(
            config.waveReward(level: 2, wave: 1),
            config.waveReward(level: 1, wave: 1)
        )
    }
}
