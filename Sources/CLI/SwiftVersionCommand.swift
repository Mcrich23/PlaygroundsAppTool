import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `swift-version` parent command
struct SwiftVersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-version",
        abstract: "Manage the swiftLanguageVersions requirement for a Swift Playground.",
        subcommands: [SetSwiftVersion.self, RemoveSwiftVersion.self]
    )
}

struct SetSwiftVersion: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
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

struct RemoveSwiftVersion: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Removes the Swift language version requirement from Package.swift."
    )

    @OptionGroup var options: ToolOptions

    mutating func run() async throws {
        let packageURL = options.packagePath
        print("Loading Package.swift at \(packageURL.path)...")
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        
        print("Removing Swift language version property...")
        try await packageFile.removeSwiftVersion()
        
        try await packageFile.write()
        print("Success!")
    }
}
