import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `set-platform` CLI command implementation
struct SetPlatform: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-platform",
        abstract: "Sets the minimum platform version in a Swift Playground's Package.swift."
    )

    @OptionGroup var options: ToolOptions

    @Argument(help: "The platform to target (e.g. iOS, macOS, tvOS, watchOS, visionOS).")
    var platform: String

    @Argument(help: "The minimum version to set (e.g. 17.0).")
    var version: String

    mutating func run() async throws {
        guard let packagePlatform = PackagePlatform(rawValue: platform) else {
            print("Error: '\(platform)' is not a valid platform. Valid options: \(PackagePlatform.allCases.map(\.rawValue).joined(separator: ", "))")
            throw ExitCode.failure
        }

        let packageURL = options.packagePath
        print("Loading Package.swift at \(packageURL.path)...")
        
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        
        print("Setting minimum platform \(packagePlatform.rawValue) to \(version)...")
        try await packageFile.setMinimumPlatform(packagePlatform, version: version)
        
        print("Saving changes...")
        try await packageFile.write()
        
        print("Success! Updated the platform version.")
    }
}
