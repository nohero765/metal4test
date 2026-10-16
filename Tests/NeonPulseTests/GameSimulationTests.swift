import XCTest
@testable import NeonPulse

final class GameSimulationTests: XCTestCase {
    func testJumpLeavesGround() {
        var game = GameSimulation()
        game.jump()
        game.update(deltaTime: 1 / 60)
        XCTAssertFalse(game.player.grounded)
        XCTAssertGreaterThan(game.player.position.y, 0)
    }

    func testSpikeKillsPlayer() {
        var game = GameSimulation()
        for _ in 0..<60 {
            game.update(deltaTime: 1 / 60)
        }
        XCTAssertFalse(game.player.alive)
    }

    func testResetRestoresPlayer() {
        var game = GameSimulation()
        game.jump()
        game.update(deltaTime: 0.2)
        game.reset()
        XCTAssertEqual(game.player.position, SIMD2<Float>(2, 0))
        XCTAssertTrue(game.player.alive)
        XCTAssertEqual(game.restartCount, 1)
    }

    func testProgressIsBounded() {
        var game = GameSimulation()
        for _ in 0..<1000 {
            game.update(deltaTime: 1 / 60)
        }
        XCTAssertGreaterThanOrEqual(game.progress, 0)
        XCTAssertLessThanOrEqual(game.progress, 1)
    }

    func testCompletionStopsSimulation() {
        var game = GameSimulation()
        for _ in 0..<2000 where !game.player.completed && game.player.alive {
            game.update(deltaTime: 1 / 60)
            if !game.player.grounded { game.jump() }
        }
        XCTAssertTrue(game.player.completed || !game.player.alive)
    }
}
