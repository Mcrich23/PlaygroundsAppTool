import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Platform Names

/// Supported Swift Package Manager platform identifiers.
public enum PackagePlatform: String, CaseIterable, Sendable {
    case iOS

    /// The member expression name used in `PackageDescription` (e.g. `.iOS("17.0")`).
    public var memberName: String { rawValue }
}

// MARK: - Errors

public enum PlatformEditorError: Error, LocalizedError {
    case packageCallNotFound
    case invalidVersion(String)

    public var errorDescription: String? {
        switch self {
        case .packageCallNotFound:
            return "Could not locate the Package(…) initialiser call in Package.swift."
        case .invalidVersion(let v):
            return "'\(v)' is not a valid platform version string."
        }
    }
}

// MARK: - Rewriter

/// A `SyntaxRewriter` that sets the minimum version for a given platform in
/// the `platforms: […]` argument of the top-level `Package(…)` call.
///
/// - If the platform is already listed, its version string is replaced.
/// - If the platform is absent but a `platforms:` argument exists, a new entry is appended.
/// - If there is no `platforms:` argument at all, one is inserted after the `name:` argument.
public final class SetMinimumPlatformRewriter: SyntaxRewriter {
    // ... logic remains untouched until here ...
    public let platform: PackagePlatform
    public let version: String

    private var foundPackageCall = false

    public init(platform: PackagePlatform, version: String) {
        self.platform = platform
        self.version = version
    }

    // MARK: - SyntaxRewriter overrides

    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        // We only care about the top-level `Package(…)` call.
        guard isToplevelPackageCall(node) else {
            return super.visit(node)
        }
        foundPackageCall = true

        let updatedArgs = rewritePlatformsArgument(in: node.arguments)
        let updatedNode = node.with(\.arguments, updatedArgs)
        return ExprSyntax(updatedNode)
    }

    // MARK: - Helpers

    private func isToplevelPackageCall(_ node: FunctionCallExprSyntax) -> Bool {
        guard let callee = node.calledExpression.as(DeclReferenceExprSyntax.self) else { return false }
        return callee.baseName.text == "Package"
    }

    /// Rewrites the `platforms:` argument list, or inserts one if missing.
    private func rewritePlatformsArgument(in args: LabeledExprListSyntax) -> LabeledExprListSyntax {
        // Try to patch an existing `platforms:` argument.
        if args.contains(where: { $0.label?.text == "platforms" }) {
            return LabeledExprListSyntax(args.map { arg in
                guard arg.label?.text == "platforms" else { return arg }
                let newExpr = rewritePlatformArray(arg.expression)
                return arg.with(\.expression, newExpr)
            })
        }

        // No `platforms:` argument — insert one after `name:` (or at the front).
        return insertPlatformsArgument(into: args)
    }

    /// Rewrites the array literal that is the value of `platforms: […]`.
    private func rewritePlatformArray(_ expr: ExprSyntax) -> ExprSyntax {
        guard var arrayExpr = expr.as(ArrayExprSyntax.self) else {
            return expr
        }

        let targetMember = platform.memberName
        let newElement = makePlatformElement()

        // Replace an existing entry for this platform.
        if arrayExpr.elements.contains(where: { elementMatchesPlatform($0.expression, name: targetMember) }) {
            let newElements = ArrayElementListSyntax(arrayExpr.elements.map { element in
                guard elementMatchesPlatform(element.expression, name: targetMember) else { return element }
                return element
                    .with(\.expression, newElement)
                    .with(\.leadingTrivia, element.leadingTrivia)
                    .with(\.trailingTrivia, element.trailingTrivia)
            })
            arrayExpr = arrayExpr.with(\.elements, newElements)
            return ExprSyntax(arrayExpr)
        }

        // Append a new entry.
        let existingElements = arrayExpr.elements

        // Add a trailing comma to the last existing element if needed.
        var updatedExisting = Array(existingElements)
        if !updatedExisting.isEmpty {
            let last = updatedExisting.removeLast()
            let withComma = last.with(\.trailingComma, .commaToken(trailingTrivia: .space))
            updatedExisting.append(withComma)
        }

        // The new element inherits leading trivia from the previous last element.
        let leadingTrivia: Trivia = updatedExisting.last?.leadingTrivia ?? .newline
        let appendedElement = ArrayElementSyntax(
            leadingTrivia: leadingTrivia,
            expression: newElement,
            trailingComma: nil
        )
        updatedExisting.append(appendedElement)
        arrayExpr = arrayExpr.with(\.elements, ArrayElementListSyntax(updatedExisting))
        return ExprSyntax(arrayExpr)
    }

    /// Checks whether an expression is a `.Platform("x.y")` call for `platform`.
    private func elementMatchesPlatform(_ expr: ExprSyntax, name: String) -> Bool {
        guard let call = expr.as(FunctionCallExprSyntax.self),
              let member = call.calledExpression.as(MemberAccessExprSyntax.self) else { return false }
        return member.declName.baseName.text == name
    }

    /// Builds a `.Platform("version")` expression token, e.g. `.iOS("17.0")`.
    private func makePlatformElement() -> ExprSyntax {
        let source = ".\(platform.memberName)(\"\(version)\")"
        return Parser.parse(source: source).statements.first!.item.as(ExprSyntax.self)!
    }

    /// Inserts a brand-new `platforms: [.Platform("version")]` argument into the call.
    private func insertPlatformsArgument(into args: LabeledExprListSyntax) -> LabeledExprListSyntax {
        let platformEntry = makePlatformElement()
        let arraySource = "[\(platformEntry.description)]"
        let arrayExpr = Parser.parse(source: arraySource).statements.first!.item.as(ExprSyntax.self)!

        // Build the new labeled argument.
        var newArg = LabeledExprSyntax(
            label: .identifier("platforms"),
            colon: .colonToken(trailingTrivia: .space),
            expression: arrayExpr,
            trailingComma: .commaToken()
        )

        // Use the same leading trivia as the first existing argument (usually a newline+indent).
        if let first = args.first {
            newArg = newArg.with(\.leadingTrivia, first.leadingTrivia)
        }

        // Insert after the `name:` argument if present, otherwise prepend.
        var result = Array(args)
        if let nameIdx = result.firstIndex(where: { $0.label?.text == "name" }) {
            result.insert(newArg, at: result.index(after: nameIdx))
        } else {
            result.insert(newArg, at: result.startIndex)
        }
        return LabeledExprListSyntax(result)
    }
}

// MARK: - Rewriter (Remove Platform)

/// A `SyntaxRewriter` that removes a specific platform from the `.platforms` array.
public final class RemovePlatformRewriter: SyntaxRewriter {
    public let platform: String
    private var foundPackageCall = false

    public init(platform: String) {
        self.platform = platform
    }

    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard isToplevelPackageCall(node) else {
            return super.visit(node)
        }
        foundPackageCall = true

        let args = node.arguments
        let updatedArgs = LabeledExprListSyntax(args.map { arg -> LabeledExprSyntax in
            guard arg.label?.text == "platforms" else { return arg }
            let patchedArray = rewritePlatformsArray(arg.expression)
            return arg.with(\.expression, patchedArray)
        })

        let updatedNode = node.with(\.arguments, updatedArgs)
        return ExprSyntax(updatedNode)
    }

    private func isToplevelPackageCall(_ node: FunctionCallExprSyntax) -> Bool {
        if let identifier = node.calledExpression.as(DeclReferenceExprSyntax.self),
           identifier.baseName.text == "Package" {
            return true
        }
        return false
    }

    private func rewritePlatformsArray(_ expr: ExprSyntax) -> ExprSyntax {
        guard let arrayExpr = expr.as(ArrayExprSyntax.self) else { return expr }

        var remainingElements = arrayExpr.elements.filter { element in
            // Parse something like `.iOS("17.0")` or `.macOS(.v12)`
            if let callExpr = element.expression.as(FunctionCallExprSyntax.self),
               let memberExpr = callExpr.calledExpression.as(MemberAccessExprSyntax.self) {
                return memberExpr.declName.baseName.text != platform
            } else if let memberExpr = element.expression.as(MemberAccessExprSyntax.self) {
                return memberExpr.declName.baseName.text != platform
            }
            return true
        }

        if let last = remainingElements.last {
            let lastIndex = remainingElements.index(before: remainingElements.endIndex)
            remainingElements[lastIndex] = last.with(\.trailingComma, nil)
        }

        return ExprSyntax(arrayExpr.with(\.elements, ArrayElementListSyntax(remainingElements)))
    }
}

// MARK: - Visitor (List Platforms)

/// A `SyntaxVisitor` that extracts the `platforms: [...]` argument of the top-level `Package(...)` call.
public final class GetPlatformsVisitor: SyntaxVisitor {
    public private(set) var platforms: [PackagePlatform: String] = [:]
    private var foundPackageCall = false

    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard isToplevelPackageCall(node) else {
            return .visitChildren
        }
        guard !foundPackageCall else { return .skipChildren }
        foundPackageCall = true

        if let platformsArg = node.arguments.first(where: { $0.label?.text == "platforms" }),
           let arrayExpr = platformsArg.expression.as(ArrayExprSyntax.self) {
            for element in arrayExpr.elements {
                if let callExpr = element.expression.as(FunctionCallExprSyntax.self),
                   let memberAccess = callExpr.calledExpression.as(MemberAccessExprSyntax.self) {
                    let platformName = memberAccess.declName.baseName.text
                    let version = callExpr.arguments.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue ?? ""
                    if let pkgPlatform = PackagePlatform(rawValue: platformName) {
                        platforms[pkgPlatform] = version
                    }
                } else if let memberAccess = element.expression.as(MemberAccessExprSyntax.self) {
                    let platformName = memberAccess.declName.baseName.text
                    if let pkgPlatform = PackagePlatform(rawValue: platformName) {
                        platforms[pkgPlatform] = ""
                    }
                }
            }
        }
        
        return .skipChildren
    }

    private func isToplevelPackageCall(_ node: FunctionCallExprSyntax) -> Bool {
        guard let callee = node.calledExpression.as(DeclReferenceExprSyntax.self) else { return false }
        return callee.baseName.text == "Package"
    }
}

// MARK: - Convenience Entry Point

public extension PackageSwiftFile {
    /// Gets the current platform minimums configured in the Package.swift.
    func getPlatforms() async throws -> [PackagePlatform: String] {
        let syntaxToRead = self.syntax
        return await Task {
            let visitor = GetPlatformsVisitor(viewMode: .sourceAccurate)
            visitor.walk(syntaxToRead)
            return visitor.platforms
        }.value
    }

    /// Sets the minimum SDK version for `platform` in the parsed Package.swift.
    ///
    /// - Parameters:
    ///   - platform: The target platform (e.g. `.iOS`, `.macOS`).
    ///   - version: The version string (e.g. `"17.0"`).
    /// - Throws: `PlatformEditorError` on parse failures.
    mutating func setMinimumPlatform(_ platform: PackagePlatform, version: String) async throws {
        let syntaxToRewrite = self.syntax
        let rewritten = await Task {
            let rewriter = SetMinimumPlatformRewriter(platform: platform, version: version)
            return rewriter.visit(syntaxToRewrite).as(SourceFileSyntax.self)!
        }.value
        apply(rewritten: rewritten)
    }

    /// Removes a platform requirement from the `.platforms` array using `RemovePlatformRewriter`.
    mutating func removePlatform(_ platform: String) async throws {
        let syntaxToRewrite = self.syntax
        
        let rewritten = await Task {
            let rewriter = RemovePlatformRewriter(platform: platform)
            return rewriter.visit(syntaxToRewrite).as(SourceFileSyntax.self)!
        }.value
        apply(rewritten: rewritten)
    }
}
