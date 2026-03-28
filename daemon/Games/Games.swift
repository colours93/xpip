import Foundation

/// Central registry of all game types. Games are created via factory method
/// so multiple instances can run simultaneously on different PiPs.
enum Games {
    static let gameNames: [String] = [
        "pipong", "pipong2", "flappy", "bounce", "invaders", "frogger",
        "runner", "snake", "breakout", "asteroids", "cursorhunt", "doodlejump", "pacman",
        "mario", "doom"
    ]

    /// Create a fresh game instance by name.
    static func create(_ name: String) -> MiniGame? {
        switch name {
        case "pipong": return PiPongGame()
        case "pipong2": return PiPong2Game()
        case "flappy": return FlappyGame()
        case "bounce": return BounceGame()
        case "invaders": return InvadersGame()
        case "frogger": return FroggerGame()
        case "runner": return RunnerGame()
        case "snake": return SnakeGame()
        case "breakout": return BreakoutGame()
        case "asteroids": return AsteroidsGame()
        case "cursorhunt": return CursorHuntGame()
        case "doodlejump": return DoodleJumpGame()
        case "pacman": return PacManGame()
        case "mario": return MarioGame()
        case "doom": return DoomGame()
        default: return nil
        }
    }
}
