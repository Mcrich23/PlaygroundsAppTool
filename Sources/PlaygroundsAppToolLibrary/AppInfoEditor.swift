import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Errors

public enum AppInfoEditorError: Error, LocalizedError {
    case applicationProductNotFound

    public var errorDescription: String? {
        switch self {
        case .applicationProductNotFound:
            return "Could not find an .iOSApplication or .macOSApplication product declaration in Package.swift."
        }
    }
}

// MARK: - Rewriter

/// A `SyntaxRewriter` that injects an `additionalInfoPlistContentFilePath: "filename"`
/// argument into the first `.iOSApplication(…)` or `.macOSApplication(…)` product call in `Package.swift`.
public final class AppInfoEditor: SyntaxRewriter {
    public let filename: String
    
    private var foundAppProduct = false

    public init(filename: String = "Info.plist") {
        self.filename = filename
    }

    /// Whether the target was successfully found and patched during the visit.
    public var didApplyPatch: Bool { foundAppProduct }

    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        // We only care about `.iOSApplication(...)` or `.macOSApplication(...)` calls.
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
              (memberAccess.declName.baseName.text == "iOSApplication" || memberAccess.declName.baseName.text == "macOSApplication") else {
            return super.visit(node)
        }

        // We found our app product call. Only patch the first one we find.
        guard !foundAppProduct else { return super.visit(node) }
        foundAppProduct = true

        // If it already has an infoPlist related argument, do not touch it.
        let args = node.arguments
        if args.contains(where: {
            let text = $0.label?.text
            return text == "additionalInfoPlistContentFilePath" || text == "infoPlist"
        }) {
            return super.visit(node)
        }

        let updatedArgs = insertInfoPlistArgument(into: args)
        let updatedNode = node.with(\.arguments, updatedArgs)
        return ExprSyntax(updatedNode)
    }

    // MARK: - Helpers

    /// Inserts the `additionalInfoPlistContentFilePath` at the end of the arguments list.
    /// Order is typically less strict in `.iOSApplication` but placing it at the end is conventional.
    private func insertInfoPlistArgument(into args: LabeledExprListSyntax) -> LabeledExprListSyntax {
        var result = Array(args)
        let src = "additionalInfoPlistContentFilePath: \"\(filename)\""
        
        let parsedStmt = Parser.parse(source: "call(\(src))").statements.first!.item
        guard let callExpr = parsedStmt.as(ExprSyntax.self)?.as(FunctionCallExprSyntax.self),
              var newArg = callExpr.arguments.first else {
            return args
        }

        // We will append it to the end. Ensure the previously last element has a trailing comma.
        if !result.isEmpty {
            let lastIndex = result.count - 1
            let lastElement = result[lastIndex]
            if lastElement.trailingComma == nil {
                result[lastIndex] = lastElement.with(\.trailingComma, .commaToken())
            }
            
            // Match the indentation of the previous last element
            let prevTrivia = lastElement.leadingTrivia
            newArg = newArg.with(\.leadingTrivia, prevTrivia)
        } else {
            newArg = newArg.with(\.leadingTrivia, .newline)
        }
        
        result.append(newArg)
        return LabeledExprListSyntax(result)
    }
}

// MARK: - Rewriter (Remove Info Plist)

/// A `SyntaxRewriter` that removes the `additionalInfoPlistContentFilePath`
/// argument from the first `.iOSApplication(…)` or `.macOSApplication(…)` product.
public final class RemoveAppInfoRewriter: SyntaxRewriter {
    public private(set) var didApplyPatch: Bool = false
    
    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
              (memberAccess.declName.baseName.text == "iOSApplication" || memberAccess.declName.baseName.text == "macOSApplication") else {
            return super.visit(node)
        }

        guard !didApplyPatch else { return super.visit(node) }
        didApplyPatch = true

        let args = node.arguments
        var remainingArgs = args.filter { arg in
            let text = arg.label?.text
            return text != "additionalInfoPlistContentFilePath" && text != "infoPlist"
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
    /// Injects `additionalInfoPlistContentFilePath: "filename"` into the `.iOSApplication` product.
    mutating func initInfoPlist(filename: String = "Info.plist") async throws {
        let syntaxToRewrite = self.syntax
        
        let result = await Task {
            let rewriter = AppInfoEditor(filename: filename)
            let rewritten = rewriter.visit(syntaxToRewrite).as(SourceFileSyntax.self)!
            return (didApplyPatch: rewriter.didApplyPatch, rewritten: rewritten)
        }.value

        if !result.didApplyPatch {
            throw AppInfoEditorError.applicationProductNotFound
        }

        apply(rewritten: result.rewritten)
    }

    /// Removes `additionalInfoPlistContentFilePath` from the application product.
    mutating func removeInfoPlist() async throws {
        let syntaxToRewrite = self.syntax
        
        let result = await Task {
            let rewriter = RemoveAppInfoRewriter()
            let rewritten = rewriter.visit(syntaxToRewrite).as(SourceFileSyntax.self)!
            return (didApplyPatch: rewriter.didApplyPatch, rewritten: rewritten)
        }.value

        if !result.didApplyPatch {
            throw AppInfoEditorError.applicationProductNotFound
        }

        apply(rewritten: result.rewritten)
    }
}
