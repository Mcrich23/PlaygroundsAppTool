import Foundation
import SwiftSyntax
import SwiftParser

public enum AppInfoStateWriterError: Error, LocalizedError {
    case applicationProductNotFound

    public var errorDescription: String? {
        switch self {
        case .applicationProductNotFound:
            return "Could not find an .iOSApplication or .macOSApplication product declaration in Package.swift."
        }
    }
}

/// A `SyntaxRewriter` that injects or updates app info like name, id, teamIdentifier, etc.
/// in the first `.iOSApplication(…)` or `.macOSApplication(…)` product call in `Package.swift`.
public final class AppInfoStateWriter: SyntaxRewriter {
    public let appInfo: AppInfo
    public private(set) var foundAppProduct: Bool = false

    public init(appInfo: AppInfo) {
        self.appInfo = appInfo
    }

    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
              (memberAccess.declName.baseName.text == "iOSApplication" || memberAccess.declName.baseName.text == "macOSApplication") else {
            return super.visit(node)
        }

        guard !foundAppProduct else { return super.visit(node) }
        foundAppProduct = true

        var args = Array(node.arguments)
        
        func updateArg(label: String, altLabels: [String] = [], stringValue: String?) {
            let existingIdx = args.firstIndex { 
                let t = $0.label?.text
                return t == label || altLabels.contains(t ?? "")
            }
            
            if let newValue = stringValue, !newValue.isEmpty {
                let parsedStmt = Parser.parse(source: "\"\(newValue)\"").statements.first!.item
                let expr = parsedStmt.as(ExprSyntax.self)!
                if let idx = existingIdx {
                    args[idx] = args[idx].with(\.expression, expr).with(\.trailingComma, nil)
                } else {
                    let newArg = LabeledExprSyntax(
                        label: .identifier(label),
                        colon: .colonToken(trailingTrivia: .space),
                        expression: expr,
                        trailingComma: nil
                    )
                    args.append(newArg)
                }
            } else {
                if let idx = existingIdx {
                    args.remove(at: idx)
                }
            }
        }
        
        updateArg(label: "name", stringValue: appInfo.name)
        updateArg(label: "id", altLabels: ["bundleIdentifier"], stringValue: appInfo.id)
        updateArg(label: "teamIdentifier", stringValue: appInfo.teamIdentifier)
        updateArg(label: "displayVersion", altLabels: ["version"], stringValue: appInfo.displayVersion)
        updateArg(label: "bundleVersion", altLabels: ["buildNumber"], stringValue: appInfo.bundleVersion)
        
        // Fix up trailing commas and trivia for a clean look
        for i in 0..<args.count {
            if i < args.count - 1 {
                args[i] = args[i].with(\.trailingComma, .commaToken())
            } else {
                args[i] = args[i].with(\.trailingComma, nil)
            }
            
            // Standard formatting for .iOSApplication parameters
            args[i] = args[i].with(\.leadingTrivia, .newline + .spaces(8))
        }
        
        let updatedNode = node.with(\.arguments, LabeledExprListSyntax(args))
        return ExprSyntax(updatedNode)
    }
}

public extension PackageSwiftFile {
    /// Rewrites Basic App Info in the Package.swift.
    mutating func setAppInfo(_ appInfo: AppInfo) async throws {
        let syntaxToRewrite = self.syntax
        
        let result = await Task {
            let rewriter = AppInfoStateWriter(appInfo: appInfo)
            let rewritten = rewriter.visit(syntaxToRewrite)
            return (didApplyPatch: rewriter.foundAppProduct, rewritten: rewritten)
        }.value

        if !result.didApplyPatch {
            throw AppInfoStateWriterError.applicationProductNotFound
        }

        apply(rewritten: result.rewritten)
    }
}
