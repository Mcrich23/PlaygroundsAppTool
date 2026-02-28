import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `versions` parent command
struct VersionsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "versions",
        abstract: "Manage the minimum platform and Swift language versions for a Swift Playground.",
        subcommands: [IOSVersionCommand.self, SwiftVersionSubcommand.self]
    )
}

struct IOSVersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "iOS",
        abstract: "Sets the minimum iOS version in a Swift Playground's Package.swift."
    )

    @OptionGroup var options: ToolOptions

    @Argument(help: "The minimum iOS version to set (e.g. 17.0).")
    var version: String

    mutating func run() async throws {
        let packageURL = options.packagePath
        print("Loading Package.swift at \(packageURL.path)...")
        
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        
        print("Setting minimum platform iOS to \(version)...")
        try await packageFile.setMinimumPlatform(.iOS, version: version)
        
        print("Saving changes...")
        try await packageFile.write()
        
        print("Success! Updated the platform version.")
    }
}

struct SwiftVersionSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift",
        abstract: "Sets the Swift language version in a Package.swift."
    )

    @OptionGroup var options: ToolOptions

    @Argument(help: "The Swift language version to set (e.g. 6, 5.9, etc).")
    var version: String

    mutating func run() async throws {
        let packageURL = options.packagePath
        print("Loading Package.swift at \(packageURL.path)...")
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        
        print("Setting Swift language version to \(version)...")
        try await packageFile.setSwiftVersion(version)
        
        try await packageFile.write()
        print("Success!")
    }
}
