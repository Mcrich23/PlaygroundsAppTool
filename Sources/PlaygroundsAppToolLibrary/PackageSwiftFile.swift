import Foundation
import SwiftParser
import SwiftSyntax

/// Represents a loaded and parsed `Package.swift` file.
public struct PackageSwiftFile: Sendable {
    /// The URL of the `Package.swift` file.
    public let url: URL

    /// The raw source text read from disk.
    public private(set) var source: String

    /// The parsed syntax tree.
    public private(set) var syntax: SourceFileSyntax

    // MARK: - Init

    /// Asynchronously loads and parses the `Package.swift` at the given URL.
    public static func load(from url: URL) async throws -> PackageSwiftFile {
        return try await Task {
            let source = try String(contentsOf: url, encoding: .utf8)
            let syntax = Parser.parse(source: source)
            return PackageSwiftFile(url: url, source: source, syntax: syntax)
        }.value
    }

    /// Asynchronously loads and parses the `Package.swift` from a `.swiftpm` project directory.
    /// - Parameter projectURL: Path to the `.swiftpm` directory (or the `Package.swift` file itself).
    public static func load(fromProject projectURL: URL) async throws -> PackageSwiftFile {
        var fileURL = projectURL
        if projectURL.lastPathComponent != "Package.swift" {
            fileURL = projectURL.appendingPathComponent("Package.swift")
        }
        return try await load(from: fileURL)
    }

    private init(url: URL, source: String, syntax: SourceFileSyntax) {
        self.url = url
        self.source = source
        self.syntax = syntax
    }

    // MARK: - Mutation

    /// Replaces the internal syntax tree (used by editors after a rewrite).
    public mutating func apply(rewritten: SourceFileSyntax) {
        self.syntax = rewritten
    }

    // MARK: - Persistence

    /// Asynchronously writes the current (possibly rewritten) syntax back to the original file.
    public func write() async throws {
        let updatedSource = syntax.description
        let targetURL = self.url
        try await Task {
            try updatedSource.write(to: targetURL, atomically: true, encoding: .utf8)
        }.value
    }
}
