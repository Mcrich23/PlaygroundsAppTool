import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Errors

public enum TargetResourcesEditorError: Error, LocalizedError {
    case targetNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .targetNotFound(let name):
            return "Could not find a target named '\(name)' in Package.swift."
        }
    }
}

// MARK: - Rewriter

/// A `SyntaxRewriter` that injects a `resources: [.process("Resources")]` argument
/// into a specific target (usually an `.executableTarget`) in `Package.swift`.
public final class TargetResourcesEditor: SyntaxRewriter {
    public let targetName: String
    
    private var foundTarget = false

    public init(targetName: String = "AppModule") {
        self.targetName = targetName
    }

    /// Whether the target was successfully found and patched during the visit.
    public var didApplyPatch: Bool { foundTarget }

    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        // We only care about `.target(...)` or `.executableTarget(...)` containing our targetName.
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
              (memberAccess.declName.baseName.text == "target" || memberAccess.declName.baseName.text == "executableTarget") else {
            return super.visit(node)
        }

        // Verify this is the target we care about (name: "targetName")
        guard node.arguments.contains(where: {
            $0.label?.text == "name" &&
            $0.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue == targetName
        }) else {
            return super.visit(node)
        }

        // We found our target call.
        foundTarget = true

        // If it already has a `resources:` array, we don't try to merge (yet). We'll assume NO-OP or leave it alone.
        if node.arguments.contains(where: { $0.label?.text == "resources" }) {
            return super.visit(node)
        }

        let updatedArgs = insertResourcesArgument(into: node.arguments)
        let updatedNode = node.with(\.arguments, updatedArgs)
        return ExprSyntax(updatedNode)
    }

    // MARK: - Helpers

    /// SPM `Target` parameter order requires `resources` to appear after `path` / `exclude` / `sources`,
    /// but before `publicHeadersPath` / `cSettings` / `swiftSettings`.
    private func insertResourcesArgument(into args: LabeledExprListSyntax) -> LabeledExprListSyntax {
        // The labels that should strictly precede `resources`
        let precedeLabels: Set<String> = ["name", "dependencies", "path", "exclude", "sources"]

        var result = Array(args)
        var insertIndex = result.startIndex

        // Find the correct insertion index.
        for (i, arg) in result.enumerated() {
            let label = arg.label?.text ?? ""
            if precedeLabels.contains(label) {
                insertIndex = result.index(after: i)
            }
        }

        let resourcesSource = "resources: [.process(\"Resources\")]"
        let parsedStmt = Parser.parse(source: "call(\(resourcesSource))").statements.first!.item
        guard let callExpr = parsedStmt.as(ExprSyntax.self)?.as(FunctionCallExprSyntax.self),
              let resourcesArgTemplate = callExpr.arguments.first else {
            return args
        }

        var newArg = resourcesArgTemplate

        // Add a trailing comma to the previous element if we're inserting after something.
        if insertIndex > 0 {
            let prevIndex = insertIndex - 1
            let prevElement = result[prevIndex]
            if prevElement.trailingComma == nil {
                result[prevIndex] = prevElement.with(\.trailingComma, .commaToken())
            }
        }

        // Determine trivia spacing (match the indentation of the previous argument)
        if insertIndex > 0 {
            let prev = result[insertIndex - 1].leadingTrivia
            // Newline and indent from previous
            newArg = newArg.with(\.leadingTrivia, prev)
        } else {
            newArg = newArg.with(\.leadingTrivia, .newline)
        }
        
        // If we are inserting before another argument, we need a trailing comma on our new arg.
        if insertIndex < result.count {
            newArg = newArg.with(\.trailingComma, .commaToken())
        }

        result.insert(newArg, at: insertIndex)
        return LabeledExprListSyntax(result)
    }
}

// MARK: - Rewriter (Remove Resources)

/// A `SyntaxRewriter` that removes the `resources:` argument from a target.
public final class RemoveTargetResourcesRewriter: SyntaxRewriter {
    public let targetName: String
    public private(set) var didApplyPatch: Bool = false

    public init(targetName: String = "AppModule") {
        self.targetName = targetName
    }

    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
              (memberAccess.declName.baseName.text == "executableTarget" || memberAccess.declName.baseName.text == "target") else {
            return super.visit(node)
        }

        let args = node.arguments
        let isCorrectTarget = args.contains { arg in
            arg.label?.text == "name" && arg.expression.description == "\"\(targetName)\""
        }
        
        guard isCorrectTarget else { return super.visit(node) }
        guard !didApplyPatch else { return super.visit(node) }
        didApplyPatch = true

        var remainingArgs = args.filter { arg in
            arg.label?.text != "resources"
        }
        
        // Strip trailing comma from the absolute last element after removal just in case.
        if let last = remainingArgs.last {
            let lastIndex = remainingArgs.index(before: remainingArgs.endIndex)
            remainingArgs[lastIndex] = last.with(\.trailingComma, nil)
        }

        let updatedNode = node.with(\.arguments, remainingArgs)
        return ExprSyntax(updatedNode)
    }
}

// MARK: - Convenience Entry Point

public extension PackageSwiftFile {
    /// Injects `resources: [.process("Resources")]` into the target mapping to `targetName`.
    mutating func initResources(targetName: String = "AppModule") async throws {
        let syntaxToRewrite = self.syntax
        
        let result = await Task {
            let rewriter = TargetResourcesEditor(targetName: targetName)
            let rewritten = rewriter.visit(syntaxToRewrite).as(SourceFileSyntax.self)!
            return (didApplyPatch: rewriter.didApplyPatch, rewritten: rewritten)
        }.value

        if !result.didApplyPatch {
            throw TargetResourcesEditorError.targetNotFound(targetName)
        }

        apply(rewritten: result.rewritten)
    }

    /// Removes the `resources:` argument from the specified target.
    mutating func removeResources(targetName: String = "AppModule") async throws {
        let syntaxToRewrite = self.syntax
        
        let result = await Task {
            let rewriter = RemoveTargetResourcesRewriter(targetName: targetName)
            let rewritten = rewriter.visit(syntaxToRewrite).as(SourceFileSyntax.self)!
            return (didApplyPatch: rewriter.didApplyPatch, rewritten: rewritten)
        }.value

        if !result.didApplyPatch {
            throw TargetResourcesEditorError.targetNotFound(targetName)
        }

        apply(rewritten: result.rewritten)
    }
}
