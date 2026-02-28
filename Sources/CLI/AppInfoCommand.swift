import Foundation
import ArgumentParser
import PlaygroundsAppToolLibrary

/// `appInfo` parent command
struct AppInfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appInfo",
        abstract: "Manage basic application information in a Swift Playground's Package.swift.",
        subcommands: [
            GetAppInfoCommand.self,
            SetCategoryCommand.self,
            SetAccentColorCommand.self,
            SetDeviceFamiliesCommand.self
        ]
    )
}

struct GetAppInfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Retrieve and print all application information."
    )

    @OptionGroup var options: ToolOptions

    mutating func run() async throws {
        let packageURL = options.packagePath
        let packageFile = try await PackageSwiftFile.load(from: packageURL)
        let appInfo = try await packageFile.getAppInfo()
        
        print("--- App Info ---")
        print("Name: \(appInfo.name ?? "Not set")")
        print("Bundle Identifier: \(appInfo.id ?? "Not set")")
        print("Team Identifier: \(appInfo.teamIdentifier ?? "Not set")")
        print("Display Version: \(appInfo.displayVersion ?? "Not set")")
        print("Bundle Version: \(appInfo.bundleVersion ?? "Not set")")
        print("App Category: \(appInfo.appCategory?.rawValue ?? "Not set")")
        
        let colorStr: String
        if let color = appInfo.accentColor {
            switch color {
            case .asset(let name): colorStr = "Asset (\(name))"
            case .presetColor(let pColor): colorStr = "Preset (\(pColor.rawValue))"
            }
        } else {
            colorStr = "Not set"
        }
        print("Accent Color: \(colorStr)")
        
        let familiesStr = appInfo.supportedDeviceFamilies.isEmpty ? "Not set" : appInfo.supportedDeviceFamilies.joined(separator: ", ")
        print("Supported Device Families: \(familiesStr)")
        print("Has Custom Info.plist: \(appInfo.hasInfoPlist)")
    }
}

// Custom parser for PresetColor
enum PresetColorParsingError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        return "Invalid preset color '\(String(describing: self))'. Valid colors: \(PresetColor.allCases.map(\.rawValue).joined(separator: ", "))"
    }
}

extension PresetColor: ExpressibleByArgument {
    public init?(argument: String) {
        if let match = PresetColor(rawValue: argument) {
            self = match
        } else {
            return nil
        }
    }
}

// Custom parser for AppCategory
enum AppCategoryParsingError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        return "Invalid app category '\(String(describing: self))'. Valid categories: \(AppCategory.allCases.map(\.rawValue).joined(separator: ", "))"
    }
}

extension AppCategory: ExpressibleByArgument {
    public init?(argument: String) {
        if let match = AppCategory(rawValue: argument) {
            self = match
        } else {
            return nil
        }
    }
}

struct SetCategoryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setCategory",
        abstract: "Sets the application category."
    )

    @OptionGroup var options: ToolOptions

    @Argument(help: "The app category (e.g. photography, games).")
    var category: AppCategory

    mutating func run() async throws {
        let packageURL = options.packagePath
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        var appInfo = try await packageFile.getAppInfo()
        
        appInfo.appCategory = category
        try await packageFile.setAppInfo(appInfo)
        try await packageFile.write()
        
        print("Successfully updated App Category to \(category.rawValue).")
    }
}

struct SetAccentColorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setAccentColor",
        abstract: "Sets the Accent Color."
    )

    @OptionGroup var options: ToolOptions

    @Option(name: .shortAndLong, help: "Preset color (e.g. blue, red).")
    var preset: PresetColor?

    @Option(name: .shortAndLong, help: "Asset name (e.g. AccentColor).")
    var asset: String?

    mutating func run() async throws {
        guard preset != nil || asset != nil else {
            print("Error: You must provide either --preset or --asset.")
            throw ExitCode.failure
        }
        
        guard preset == nil || asset == nil else {
            print("Error: You cannot provide both --preset and --asset.")
            throw ExitCode.failure
        }

        let packageURL = options.packagePath
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        var appInfo = try await packageFile.getAppInfo()
        
        if let p = preset {
            appInfo.accentColor = .presetColor(p)
        } else if let a = asset {
            appInfo.accentColor = .asset(a)
        }
        
        try await packageFile.setAppInfo(appInfo)
        try await packageFile.write()
        
        print("Successfully updated Accent Color.")
    }
}

struct SetDeviceFamiliesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setDeviceFamilies",
        abstract: "Sets the Supported Device Families."
    )

    @OptionGroup var options: ToolOptions

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "List of device families (e.g. pad phone mac).")
    var families: [String]

    mutating func run() async throws {
        let packageURL = options.packagePath
        var packageFile = try await PackageSwiftFile.load(from: packageURL)
        var appInfo = try await packageFile.getAppInfo()
        
        let validFamilies = Set(["pad", "phone", "mac", "tv", "vision"])
        for family in families {
            guard validFamilies.contains(family) else {
                print("Error: '\(family)' is not a valid device family. Valid options: \(validFamilies.joined(separator: ", "))")
                throw ExitCode.failure
            }
        }
        
        appInfo.supportedDeviceFamilies = families
        
        try await packageFile.setAppInfo(appInfo)
        try await packageFile.write()
        
        print("Successfully updated Supported Device Families.")
    }
}
