import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `init-resources` CLI command implementation
struct InitResources: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init-resources",
        abstract: "Initializes a Resources directory and hooks it into Package.swift for a specific target."
    )

    @Option(name: .shortAndLong, help: "The path to the .swiftpm project directory.")
    var project: String

    @Option(name: .shortAndLong, help: "The target name to inject resources into.")
    var target: String = "AppModule"

    mutating func run() async throws {
        let projectURL = URL(fileURLWithPath: project)
        let packageURL = projectURL.appendingPathComponent("Package.swift")
        
        guard FileManager.default.fileExists(atPath: packageURL.path) else {
            print("Error: Could not find Package.swift at \(packageURL.path)")
            throw ExitCode.failure
        }

        print("Loading Package.swift at \(packageURL.path)...")
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        
        print("Injecting resources array into target '\(target)'...")
        do {
            try await packageFile.initResources(targetName: target)
        } catch {
            print("Error modifying Package.swift: \(error.localizedDescription)")
            throw ExitCode.failure
        }
        
        print("Saving Package.swift changes...")
        try await packageFile.write()
        
        // Create the physical Resources folder
        let resourcesURL = projectURL.appendingPathComponent("Resources")
        if !FileManager.default.fileExists(atPath: resourcesURL.path) {
            print("Creating Resources directory at \(resourcesURL.path)...")
            try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        } else {
            print("Resources directory already exists.")
        }
        
        print("Success! Initialized Resources for target '\(target)'.")
    }
}
