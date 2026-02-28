import ArgumentParser

@main
struct PlaygroundsAppTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "PlaygroundsAppTool",
        abstract: "A CLI tool for managing .swiftpm Playground Apps.",
        version: "1.0.0",
        subcommands: [
            PlatformCommand.self,
            ResourcesCommand.self,
            InfoPlistCommand.self,
            OrientationCommand.self
        ]
    )
}
