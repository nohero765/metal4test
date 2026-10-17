import Foundation
import simd

public struct LevelObstacle: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case block
        case spike
        case pad
    }

    public let kind: Kind
    public let x: Float
    public let width: Float
    public let height: Float

    public init(kind: Kind, x: Float, width: Float = 1, height: Float = 1) {
        self.kind = kind
        self.x = x
        self.width = width
        self.height = height
    }
}

public struct NeonPulseLevel: Sendable, Equatable {
    public let length: Float
    public let groundY: Float
    public let obstacles: [LevelObstacle]

    public init() {
        groundY = 0
        obstacles = [
            LevelObstacle(kind: .spike, x: 8),
            LevelObstacle(kind: .spike, x: 12),
            LevelObstacle(kind: .block, x: 17, width: 2, height: 1.5),
            LevelObstacle(kind: .spike, x: 22),
            LevelObstacle(kind: .spike, x: 23),
            LevelObstacle(kind: .pad, x: 28, width: 1.5),
            LevelObstacle(kind: .block, x: 34, width: 2, height: 2),
            LevelObstacle(kind: .spike, x: 40),
            LevelObstacle(kind: .spike, x: 41),
            LevelObstacle(kind: .block, x: 47, width: 3, height: 1.5),
            LevelObstacle(kind: .spike, x: 54),
            LevelObstacle(kind: .pad, x: 60, width: 1.5),
            LevelObstacle(kind: .spike, x: 67),
            LevelObstacle(kind: .spike, x: 68),
            LevelObstacle(kind: .block, x: 74, width: 2, height: 2.5),
            LevelObstacle(kind: .spike, x: 81),
            LevelObstacle(kind: .spike, x: 82),
            LevelObstacle(kind: .pad, x: 88, width: 1.5),
            LevelObstacle(kind: .block, x: 94, width: 3, height: 1.5),
            LevelObstacle(kind: .spike, x: 102),
            LevelObstacle(kind: .spike, x: 103),
            LevelObstacle(kind: .block, x: 110, width: 2, height: 2),
            LevelObstacle(kind: .spike, x: 117),
            LevelObstacle(kind: .pad, x: 123, width: 1.5),
            LevelObstacle(kind: .spike, x: 130),
            LevelObstacle(kind: .spike, x: 131),
            LevelObstacle(kind: .block, x: 138, width: 3, height: 2),
            LevelObstacle(kind: .spike, x: 147),
            LevelObstacle(kind: .spike, x: 148),
            LevelObstacle(kind: .pad, x: 155, width: 1.5),
            LevelObstacle(kind: .block, x: 163, width: 2, height: 1.5),
            LevelObstacle(kind: .spike, x: 171),
            LevelObstacle(kind: .spike, x: 172),
            LevelObstacle(kind: .block, x: 179, width: 3, height: 2),
            LevelObstacle(kind: .spike, x: 188),
            LevelObstacle(kind: .pad, x: 194, width: 1.5),
            LevelObstacle(kind: .spike, x: 202),
            LevelObstacle(kind: .spike, x: 203),
            LevelObstacle(kind: .block, x: 210, width: 3, height: 2.5)
        ]
        length = 220
    }
}

public struct PlayerState: Sendable, Equatable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var grounded: Bool
    public var alive: Bool
    public var completed: Bool
    public var jumpPulse: Float

    public init() {
        position = SIMD2<Float>(2, 0)
        velocity = .zero
        grounded = true
        alive = true
        completed = false
        jumpPulse = 0
    }
}

public struct GameSimulation: Sendable {
    public let level: NeonPulseLevel
    public private(set) var player: PlayerState
    public private(set) var elapsed: Float
    public private(set) var restartCount: Int

    private let playerSize = SIMD2<Float>(0.8, 0.8)
    private let forwardSpeed: Float = 8.5
    private let gravity: Float = -24
    private let jumpVelocity: Float = 11.8

    public init(level: NeonPulseLevel = NeonPulseLevel()) {
        self.level = level
        player = PlayerState()
        elapsed = 0
        restartCount = 0
    }

    public var progress: Float {
        min(max((player.position.x - 2) / (level.length - 2), 0), 1)
    }

    public mutating func reset() {
        player = PlayerState()
        elapsed = 0
        restartCount += 1
    }

    public mutating func jump() {
        guard player.alive, !player.completed else { return }
        if player.grounded {
            player.velocity.y = jumpVelocity
            player.grounded = false
            player.jumpPulse = 1
        }
    }

    public mutating func updateMenuPulse(deltaTime: Float) {
        let delta = min(max(deltaTime, 0), 1 / 20)
        player.jumpPulse = max(player.jumpPulse - delta * 3, 0)
    }

    public mutating func update(deltaTime: Float) {
        guard player.alive, !player.completed else { return }
        let delta = min(max(deltaTime, 0), 1 / 20)
        elapsed += delta
        player.jumpPulse = max(player.jumpPulse - delta * 3, 0)
        player.velocity.x = forwardSpeed
        player.velocity.y += gravity * delta
        player.position += player.velocity * delta

        if player.position.y < level.groundY {
            player.position.y = level.groundY
            player.velocity.y = 0
            player.grounded = true
        }

        for obstacle in level.obstacles {
            if obstacle.x > player.position.x + 1.5 || obstacle.x + obstacle.width < player.position.x - 1.5 {
                continue
            }
            switch obstacle.kind {
            case .pad:
                if player.grounded && player.position.x + 0.35 >= obstacle.x && player.position.x <= obstacle.x + obstacle.width {
                    player.velocity.y = jumpVelocity * 1.16
                    player.grounded = false
                    player.jumpPulse = 1
                }
            case .block:
                let top = obstacle.height
                let horizontal = player.position.x + playerSize.x / 2 > obstacle.x && player.position.x - playerSize.x / 2 < obstacle.x + obstacle.width
                let fallingOnto = player.velocity.y <= 0 && player.position.y >= top - 0.12 && player.position.y <= top + 0.35
                if horizontal && fallingOnto {
                    player.position.y = top
                    player.velocity.y = 0
                    player.grounded = true
                } else if horizontal && player.position.y < top - 0.2 && player.position.y + playerSize.y > 0.05 {
                    player.alive = false
                }
            case .spike:
                let horizontal = player.position.x + playerSize.x / 2 > obstacle.x + 0.08 && player.position.x - playerSize.x / 2 < obstacle.x + 0.92
                if horizontal && player.position.y < 1.0 {
                    player.alive = false
                }
            }
            if !player.alive { return }
        }

        if player.position.x >= level.length - 2 {
            player.completed = true
            player.velocity = .zero
        }
    }
}
