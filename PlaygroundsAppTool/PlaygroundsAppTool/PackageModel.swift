import Foundation
import SwiftUI
import PlaygroundsAppToolLibrary

@Observable
public final class PackageModel {
    public var packageFile: PackageSwiftFile?
    public var packageURL: URL?
    
    // Properties to bind in UI
    public var appInfo: AppInfo = AppInfo()
    public var platforms: [PackagePlatform: String] = [:]
    public var orientations: [String] = []
    public var swiftVersion: String = ""
    public var hasResources: Bool = false
    
    // UI State
    public var isLoaded: Bool { packageFile != nil }
    public var errorMessage: String?
    
    public init() {}
    
    public func load(from url: URL) async {
        do {
            self.packageURL?.stopAccessingSecurityScopedResource()
            let accessGranted = url.startAccessingSecurityScopedResource()
            if !accessGranted {
                print("Failed to gain security scoped access to \(url)")
            }
            self.packageURL = url
            let file = try await PackageSwiftFile.load(fromProject: url)
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to load package: \(error.localizedDescription)"
            self.packageFile = nil
        }
    }
    
    public func refresh() async throws {
        guard let file = packageFile else { return }
        
        self.appInfo = try await file.getAppInfo()
        self.platforms = try await file.getPlatforms()
        self.orientations = try await file.getOrientations()
        self.swiftVersion = try await file.getSwiftVersion() ?? ""
        self.hasResources = try await file.hasResources()
    }
    
    public func saveAppInfo() async {
        guard var file = packageFile else { return }
        do {
            try await file.setAppInfo(self.appInfo)
            try await file.write()
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to save App Info: \(error.localizedDescription)"
        }
    }
    
    public func setPlatform(_ platform: PackagePlatform, version: String) async {
        guard var file = packageFile else { return }
        do {
            try await file.setMinimumPlatform(platform, version: version)
            try await file.write()
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to save Platform: \(error.localizedDescription)"
        }
    }

    public func removePlatform(_ platform: PackagePlatform) async {
        guard var file = packageFile else { return }
        do {
            try await file.removePlatform(platform.memberName)
            try await file.write()
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to remove Platform: \(error.localizedDescription)"
        }
    }
    
    public func saveSwiftVersion(_ version: String) async {
        guard var file = packageFile else { return }
        do {
            try await file.setSwiftVersion(version)
            try await file.write()
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to save Swift Version: \(error.localizedDescription)"
        }
    }
    
    public func toggleOrientation(_ orientation: String) async {
        guard var file = packageFile else { return }
        do {
            let searchStr = ".\(orientation)"
            if orientations.contains(where: { $0 == searchStr || $0.hasPrefix(searchStr + "(") }) {
                try await file.removeOrientation(orientation)
            } else {
                try await file.addOrientation(orientation)
            }
            try await file.write()
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to toggle Orientation: \(error.localizedDescription)"
        }
    }

    public func setOrientationCondition(_ orientation: String, condition: String?) async {
        guard var file = packageFile else { return }
        do {
            try await file.removeOrientation(orientation)
            if let condition = condition {
                try await file.addOrientation("\(orientation)(\(condition))")
            } else {
                try await file.addOrientation(orientation)
            }
            try await file.write()
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to set Orientation condition: \(error.localizedDescription)"
        }
    }

    public func toggleResources() async {
        guard var file = packageFile else { return }
        do {
            if hasResources {
                try await file.removeResources()
            } else {
                try await file.initResources()
            }
            try await file.write()
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to toggle Resources: \(error.localizedDescription)"
        }
    }

    public func toggleInfoPlist() async {
        guard var file = packageFile else { return }
        do {
            if appInfo.hasInfoPlist {
                try await file.removeInfoPlist()
            } else {
                try await file.initInfoPlist()
            }
            try await file.write()
            self.packageFile = file
            try await refresh()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to toggle Info.plist: \(error.localizedDescription)"
        }
    }

    deinit {
        packageURL?.stopAccessingSecurityScopedResource()
    }
}
