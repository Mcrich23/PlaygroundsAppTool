import Foundation
import ArgumentParser

/// Shared CLI options for PlaygroundsAppTool commands.
struct ToolOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "The path to the .swiftpm project directory or Package.swift file. Defaults to current directory.")
    var project: String = FileManager.default.currentDirectoryPath

    @Option(name: .shortAndLong, help: "The target name to interact with.")
    var target: String = "AppModule"

    /// The resolved URL to the `Package.swift` file.
    var packagePath: URL {
        let url = URL(fileURLWithPath: project)
        if url.lastPathComponent == "Package.swift" {
            return url
        } else {
            return url.appendingPathComponent("Package.swift")
        }
    }
}
