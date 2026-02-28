import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Rewriters

/// A `SyntaxRewriter` that sets the `swiftLanguageVersions: [.version("X")]` argument
/// in the top-level `Package(…)` call.
public final class SetSwiftVersionRewriter: SyntaxRewriter {
    public let version: String
    private var foundPackageCall = false

    public init(version: String) {
        self.version = version
    }

    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard isToplevelPackageCall(node) else {
            return super.visit(node)
        }
        foundPackageCall = true

        let args = node.arguments
        
        let newElementSource = "[.version(\"\(version)\")]"
        let newArrayExpr = Parser.parse(source: newElementSource).statements.first!.item.as(ExprSyntax.self)!

        // Create the new argument if it doesn't already exist.
        var newArg = LabeledExprSyntax(
            label: .identifier("swiftLanguageVersions"),
            colon: .colonToken(trailingTrivia: .space),
            expression: newArrayExpr,
            trailingComma: .commaToken()
        )

        // Find existing `swiftLanguageVersions` and replace it, or append.
        if args.contains(where: { $0.label?.text == "swiftLanguageVersions" }) {
            let updatedArgs = LabeledExprListSyntax(args.map { arg in
                if arg.label?.text == "swiftLanguageVersions" {
                    return arg.with(\.expression, newArrayExpr)
                }
                return arg
            })
            return ExprSyntax(node.with(\.arguments, updatedArgs))
        }

        // Add it to the end of the argument list if not found.
        var result = Array(args)
        if !result.isEmpty {
            // Append a trailing comma to the existing last element
            let lastIdx = result.index(before: result.endIndex)
            result[lastIdx] = result[lastIdx].with(\.trailingComma, .commaToken())
            
            newArg = newArg
                .with(\.leadingTrivia, .newline + .spaces(4))
                .with(\.trailingComma, nil)
        }
        
        result.append(newArg)
        return ExprSyntax(node.with(\.arguments, LabeledExprListSyntax(result)))
    }

    private func isToplevelPackageCall(_ node: FunctionCallExprSyntax) -> Bool {
        if let identifier = node.calledExpression.as(DeclReferenceExprSyntax.self),
           identifier.baseName.text == "Package" {
            return true
        }
        return false
    }
}

/// A `SyntaxRewriter` that modifies the first token's leading trivia to update the `swift-tools-version` comment.
public final class SetSwiftToolsVersionRewriter: SyntaxRewriter {
    public let version: String
    private var isFirstToken = true

    public init(version: String) {
        self.version = version
    }

    public override func visit(_ token: TokenSyntax) -> TokenSyntax {
        guard isFirstToken else { return super.visit(token) }
        isFirstToken = false
        
        var newTrivia: [TriviaPiece] = []
        var replaced = false
        
        for piece in token.leadingTrivia {
            switch piece {
            case .lineComment(let text):
                if text.hasPrefix("// swift-tools-version:") || text.hasPrefix("// swift-tools-version ") {
                    newTrivia.append(.lineComment("// swift-tools-version: \(version)"))
                    replaced = true
                } else {
                    newTrivia.append(piece)
                }
            default:
                newTrivia.append(piece)
            }
        }
        
        if !replaced {
            // If there's no tools version comment, prepend it to the top.
            newTrivia.insert(.newlines(2), at: 0)
            newTrivia.insert(.lineComment("// swift-tools-version: \(version)"), at: 0)
        }
        
        return token.with(\.leadingTrivia, Trivia(pieces: newTrivia))
    }
}

// MARK: - Visitor (Get Version)

/// A `SyntaxVisitor` that extracts the `swiftLanguageVersions` argument.
public final class GetSwiftVersionVisitor: SyntaxVisitor {
    public private(set) var swiftVersion: String?
    private var foundPackageCall = false

    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard isToplevelPackageCall(node) else {
            return .visitChildren
        }
        guard !foundPackageCall else { return .skipChildren }
        foundPackageCall = true

        if let arg = node.arguments.first(where: { $0.label?.text == "swiftLanguageVersions" }),
           let arrayExpr = arg.expression.as(ArrayExprSyntax.self),
           let firstElement = arrayExpr.elements.first,
           let callExpr = firstElement.expression.as(FunctionCallExprSyntax.self),
           let memberAccess = callExpr.calledExpression.as(MemberAccessExprSyntax.self),
           memberAccess.declName.baseName.text == "version" {
            swiftVersion = callExpr.arguments.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
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
    /// Gets the currently configured Swift language version.
    func getSwiftVersion() async throws -> String? {
        let syntaxToRead = self.syntax
        return await Task {
            let visitor = GetSwiftVersionVisitor(viewMode: .sourceAccurate)
            visitor.walk(syntaxToRead)
            return visitor.swiftVersion
        }.value
    }

    /// Modifies or inserts the `swiftLanguageVersions` array using `SetSwiftVersionRewriter`
    /// and updates the `// swift-tools-version:` comment header.
    mutating func setSwiftVersion(_ version: String) async throws {
        let syntaxToRewrite = self.syntax
        
        let rewritten = await Task {
            let toolsRewriter = SetSwiftToolsVersionRewriter(version: version)
            let withToolsVersion = toolsRewriter.visit(syntaxToRewrite)
            
            let rewriter = SetSwiftVersionRewriter(version: version)
            return rewriter.visit(withToolsVersion)
        }.value
        apply(rewritten: rewritten)
    }
}
