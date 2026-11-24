import XCTest
@testable import HauntedRoom

final class GameEngineTests: XCTestCase {
    func testIncomeOnlyRunsDuringActiveGame() {
        let engine = GameEngine()
        engine.advance(dt: 10)
        XCTAssertEqual(engine.state.coins, engine.config.startingCoins)

        engine.start()
        engine.advance(dt: 1)
        XCTAssertEqual(engine.state.coins, engine.config.startingCoins + 4)
    }

    func testBedUpgradeSpendsCoinsAndIncreasesIncome() {
        let engine = GameEngine()
        engine.start()
        XCTAssertTrue(engine.upgradeBed())
        XCTAssertEqual(engine.state.bedLevel, 2)
        XCTAssertEqual(engine.state.coins, 0)
        XCTAssertEqual(engine.incomePerSecond, 8)

        engine.advance(dt: 1)
        XCTAssertEqual(engine.state.coins, 8)
    }

    func testPurchasesRejectInsufficientCoinsAndInvalidSlots() {
        let engine = GameEngine()
        engine.start()
        XCTAssertTrue(engine.buildTurret(slot: 0))
        XCTAssertEqual(engine.state.coins, 30)
        XCTAssertFalse(engine.buildTurret(slot: 0))
        XCTAssertFalse(engine.buildTurret(slot: 1))
        XCTAssertFalse(engine.buildTurret(slot: -1))
        XCTAssertFalse(engine.buildTurret(slot: 4))
        XCTAssertFalse(engine.upgradeDoor())
    }

    func testDoorUpgradeRestoresDurability() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.setInfiniteCoins(true)
        engine.advance(dt: 1.5)
        XCTAssertEqual(engine.state.doorHealth, 212)
        let coinsBeforeUpgrade = engine.state.coins

        XCTAssertTrue(engine.upgradeDoor())
        XCTAssertEqual(engine.state.doorLevel, 2)
        XCTAssertEqual(engine.state.doorHealth, 340)
        XCTAssertEqual(engine.state.coins, coinsBeforeUpgrade)
    }

    func testTurretAndGhostFollowTheirAttackCooldowns() {
        let engine = GameEngine()
        engine.start()
        engine.buildTurret(slot: 0)

        engine.advance(dt: 0.1)
        XCTAssertEqual(engine.state.ghost?.health, 166)
        XCTAssertEqual(engine.state.doorHealth, 220)

        engine.advance(dt: 1.4)
        XCTAssertEqual(engine.state.ghost?.health, 152)
        XCTAssertEqual(engine.state.doorHealth, 212)
    }

    func testGhostDefeatGrantsRewardAndStartsNextWave() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.defeatCurrentGhost()

        XCTAssertNil(engine.state.ghost)
        XCTAssertEqual(engine.state.coins, 140)
        XCTAssertEqual(engine.waveNumber, 2)
        XCTAssertEqual(engine.state.intermissionRemaining, 5, accuracy: 0.001)

        engine.advance(dt: 4.9)
        XCTAssertNil(engine.state.ghost)
        engine.advance(dt: 0.1)
        XCTAssertEqual(engine.state.ghost?.maxHealth, 360)
        XCTAssertEqual(engine.state.doorHealth, 220)
    }

    func testDefeatingAllFiveWavesWinsAndFreezesState() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)

        for wave in 1...5 {
            XCTAssertEqual(engine.waveNumber, wave)
            XCTAssertNotNil(engine.state.ghost)
            engine.defeatCurrentGhost()
            if wave < 5 {
                engine.advance(dt: 5)
            }
        }

        XCTAssertEqual(engine.state.phase, .won)
        let finalState = engine.state
        engine.advance(dt: 100)
        XCTAssertEqual(engine.state, finalState)
        XCTAssertFalse(engine.upgradeBed())
        XCTAssertFalse(engine.buildTurret(slot: 0))
    }

    func testDoorBreakingLosesAndFreezesState() {
        let engine = GameEngine()
        engine.start()
        for _ in 0..<28 {
            engine.advance(dt: 1.5)
        }

        XCTAssertEqual(engine.state.phase, .lost)
        XCTAssertEqual(engine.state.doorHealth, 0)
        let finalState = engine.state
        engine.advance(dt: 100)
        XCTAssertEqual(engine.state, finalState)
    }

    func testInfiniteCoinsNeverDeductsOrOverflowsBalance() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.setInfiniteCoins(true)
        let originalCoins = engine.state.coins

        XCTAssertTrue(engine.upgradeBed())
        XCTAssertTrue(engine.upgradeDoor())
        for slot in 0..<4 {
            XCTAssertTrue(engine.buildTurret(slot: slot))
            while engine.turretCost(at: slot) != nil {
                XCTAssertTrue(engine.upgradeTurret(slot: slot))
            }
        }

        XCTAssertEqual(engine.state.coins, originalCoins)
        XCTAssertEqual(engine.state.bedLevel, 2)
        XCTAssertEqual(engine.state.doorLevel, 2)
        XCTAssertEqual(engine.state.turrets.compactMap { $0 }.map { $0.level }, Array(repeating: 4, count: 4))
        XCTAssertFalse(engine.buildTurret(slot: 0))
        XCTAssertFalse(engine.upgradeTurret(slot: 0))
    }

    func testInvincibleDoorIgnoresAllDamage() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.setInvincibleDoor(true)

        for _ in 0..<10 {
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
        engine.defeatCurrentGhost()
        engine.addDebugCoins()

        XCTAssertFalse(engine.state.debug.infiniteCoins)
        XCTAssertFalse(engine.state.debug.invincibleDoor)
        XCTAssertEqual(engine.state.ghost?.health, 180)
        XCTAssertEqual(engine.state.coins, 80)

        engine.setAdminMode(true)
        engine.addDebugCoins()
        XCTAssertEqual(engine.state.coins, 1_080)
    }

    func testDisablingAdminModeTurnsOffActiveCheats() {
        let engine = GameEngine()
        engine.setAdminMode(true)
        engine.setInfiniteCoins(true)
        engine.setInvincibleDoor(true)
        engine.setSpeed(4)
        engine.setAdminMode(false)

        XCTAssertEqual(engine.state.debug, DebugOptions())
    }

    func testSpeedAcceptsOnlySupportedMultipliers() {
        let engine = GameEngine()
        engine.setAdminMode(true)
        engine.setSpeed(3)
        XCTAssertEqual(engine.state.debug.speedMultiplier, 1)
        engine.setSpeed(2)
        XCTAssertEqual(engine.state.debug.speedMultiplier, 2)
        engine.setSpeed(4)
        XCTAssertEqual(engine.state.debug.speedMultiplier, 4)
    }

    func testRestartResetsProgressAndDebugOptions() {
        let engine = GameEngine()
        engine.start()
        engine.setAdminMode(true)
        engine.setInfiniteCoins(true)
        engine.setInvincibleDoor(true)
        engine.setSpeed(4)
        engine.upgradeBed()
        engine.buildTurret(slot: 0)
        engine.defeatCurrentGhost()

        engine.restart()
        XCTAssertEqual(engine.state.phase, .playing)
        XCTAssertEqual(engine.state.coins, engine.config.startingCoins)
        XCTAssertEqual(engine.state.bedLevel, 1)
        XCTAssertEqual(engine.state.doorLevel, 1)
        XCTAssertEqual(engine.state.doorHealth, 220)
        XCTAssertEqual(engine.waveNumber, 1)
        XCTAssertEqual(engine.state.ghost?.health, 180)
        XCTAssertEqual(engine.state.turrets.compactMap { $0 }.count, 0)
        XCTAssertEqual(engine.state.debug, DebugOptions())
    }

    func testInvalidTimeDoesNotAdvanceGame() {
        let engine = GameEngine()
        engine.start()
        let initialState = engine.state
        engine.advance(dt: 0)
        engine.advance(dt: -1)
        engine.advance(dt: .nan)
        engine.advance(dt: .infinity)
        XCTAssertEqual(engine.state, initialState)
    }

    func testEventsAreDrainedOnce() {
        let engine = GameEngine()
        engine.start()
        XCTAssertEqual(engine.drainEvents(), [.waveStarted(wave: 1)])
        XCTAssertTrue(engine.drainEvents().isEmpty)
    }
}
