import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `set-platform` CLI command implementation
/// `platform` parent command
struct PlatformCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "platform",
        abstract: "Manage platform requirements for a Swift Playground.",
        subcommands: [SetPlatform.self]
    )
}

struct SetPlatform: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Sets the minimum platform version in a Swift Playground's Package.swift."
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
