import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `orientation` parent command
struct OrientationCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "orientation",
        abstract: "Manage supported interface orientations for an iOS Application product.",
        subcommands: [ListOrientations.self, AddOrientation.self, RemoveOrientation.self]
    )
}

struct ListOrientations: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "Lists current interface orientations.")
    @OptionGroup var options: ToolOptions

    mutating func run() async throws {
        let packageFile = try await PackageSwiftFile.load(from: options.packagePath)
        let orientations = try await packageFile.getOrientations()
        
        if orientations.isEmpty {
            print("No orientations found.")
        } else {
            print("Configured Orientations:")
            for o in orientations {
                print(" - \(o)")
            }
        }
    }
}

struct AddOrientation: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Adds an interface orientation (e.g. portrait, landscapeRight).")
    @OptionGroup var options: ToolOptions
    
    @Argument(help: "The orientation base name to add (e.g. portrait, landscapeRight).")
    var orientation: String
    
    @Flag(help: "Restrict this orientation to iPad targets.")
    var pad: Bool = false

    @Flag(help: "Restrict this orientation to iPhone targets.")
    var phone: Bool = false

    mutating func run() async throws {
        var packageFile = try await PackageSwiftFile.load(from: options.packagePath)
        
        var orientationString = orientation
        if pad && phone {
            // Do nothing because all device families are allowed
        } else if pad {
            orientationString += "(.when(deviceFamilies: [.pad]))"
        } else if phone {
            orientationString += "(.when(deviceFamilies: [.phone]))"
        }
        
        print("Adding '.\(orientationString)' to orientations...")
        try await packageFile.addOrientation(orientationString)
        try await packageFile.write()
        print("Success!")
    }
}

struct RemoveOrientation: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Removes an interface orientation.")
    @OptionGroup var options: ToolOptions
    
    @Argument(help: "The orientation base name to remove (e.g. portrait, landscapeRight).")
    var orientation: String

    mutating func run() async throws {
        var packageFile = try await PackageSwiftFile.load(from: options.packagePath)
        print("Removing '.\(orientation)' from orientations...")
        try await packageFile.removeOrientation(orientation)
        try await packageFile.write()
        print("Success!")
    }
}
