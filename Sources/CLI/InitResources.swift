import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `init-resources` CLI command implementation
struct InitResources: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init-resources",
        abstract: "Initializes a Resources directory and hooks it into Package.swift for a specific target."
    )

    @OptionGroup var options: ToolOptions

    mutating func run() async throws {
        let packageURL = options.packagePath
        
        guard FileManager.default.fileExists(atPath: packageURL.path) else {
            print("Error: Could not find Package.swift at \(packageURL.path)")
            throw ExitCode.failure
        }

        print("Loading Package.swift at \(packageURL.path)...")
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        
        print("Injecting resources array into target '\(options.target)'...")
        do {
            try await packageFile.initResources(targetName: options.target)
        } catch {
            print("Error modifying Package.swift: \(error.localizedDescription)")
            throw ExitCode.failure
        }
        
        print("Saving Package.swift changes...")
        try await packageFile.write()
        
        // Create the physical Resources folder
        // For standard swiftpm, Resources is usually inside the target folder, but for simple playgrounds,
        // it may be at the project root or a subpath depending on path arguments.
        // We'll place it in the same directory as the Package.swift.
        let projectRootURL = packageURL.deletingLastPathComponent()
        let resourcesURL = projectRootURL.appendingPathComponent("Resources")
        if !FileManager.default.fileExists(atPath: resourcesURL.path) {
            print("Creating Resources directory at \(resourcesURL.path)...")
            try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        } else {
            print("Resources directory already exists.")
        }
        
        print("Success! Initialized Resources for target '\(options.target)'.")
    }
}
