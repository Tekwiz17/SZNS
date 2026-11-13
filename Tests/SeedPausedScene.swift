import Foundation

@main
enum SeedPausedScene {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var settings = Preferences()
        settings.welcomed = true
        settings.pausedUntil = Date().addingTimeInterval(12)
        try JSONEncoder().encode(settings).write(to: url, options: .atomic)
    }
}
