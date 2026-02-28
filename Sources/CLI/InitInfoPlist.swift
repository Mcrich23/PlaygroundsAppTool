import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `info-plist` parent command
struct InfoPlistCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info-plist",
        abstract: "Manage Info.plist files linked to the application product.",
        subcommands: [InitInfoPlist.self, RemoveInfoPlist.self]
    )
}

struct InitInfoPlist: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initializes an Info.plist file and links it into the Package.swift app product."
    )

    @OptionGroup var options: ToolOptions

    @Option(name: .shortAndLong, help: "The filename of the new Plist.")
    var filename: String = "Info.plist"

    mutating func run() async throws {
        let packageURL = options.packagePath
        
        guard FileManager.default.fileExists(atPath: packageURL.path) else {
            print("Error: Could not find Package.swift at \(packageURL.path)")
            throw ExitCode.failure
        }

        print("Loading Package.swift at \(packageURL.path)...")
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        
        print("Injecting Info.plist path into application product...")
        do {
            try await packageFile.initInfoPlist(filename: filename)
        } catch {
            print("Error modifying Package.swift: \(error.localizedDescription)")
            throw ExitCode.failure
        }
        
        print("Saving Package.swift changes...")
        try await packageFile.write()
        
        // Create the physical Info.plist file
        let projectRootURL = packageURL.deletingLastPathComponent()
        let plistURL = projectRootURL.appendingPathComponent(filename)
        
        if !FileManager.default.fileExists(atPath: plistURL.path) {
            print("Creating empty \(filename) at \(plistURL.path)...")
            
            let templateXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            	<key>ITSAppUsesNonExemptEncryption</key>
            	<false/>
            </dict>
            </plist>
            
            """
            
            do {
                try templateXML.write(to: plistURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error creating \(filename): \(error.localizedDescription)")
                throw ExitCode.failure
            }
        } else {
            print("\(filename) already exists, skipping creation.")
        }
        
        print("Success! Initialized \(filename) for the project.")
    }
}

struct RemoveInfoPlist: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Removes the Info.plist link from the Package.swift product."
    )

    @OptionGroup var options: ToolOptions

    mutating func run() async throws {
        let packageURL = options.packagePath
        print("Loading Package.swift at \(packageURL.path)...")
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        
        print("Removing Info.plist property from application product...")
        do {
            try await packageFile.removeInfoPlist()
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
        
        try await packageFile.write()
        print("Success!")
    }
}
