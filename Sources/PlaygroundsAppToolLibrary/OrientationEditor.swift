import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Errors

public enum OrientationEditorError: Error, LocalizedError {
    case applicationProductNotFound
    case orientationsArgumentNotFound

    public var errorDescription: String? {
        switch self {
        case .applicationProductNotFound:
            return "Could not find an .iOSApplication product declaration in Package.swift."
        case .orientationsArgumentNotFound:
            return "Could not find a 'supportedInterfaceOrientations' argument in the .iOSApplication product."
        }
    }
}

// MARK: - Visitor (List)

/// A `SyntaxVisitor` that extracts the currently configured `supportedInterfaceOrientations`
/// array from the first `.iOSApplication(…)` product call in `Package.swift`.
public final class GetOrientationsVisitor: SyntaxVisitor {
    public private(set) var orientations: [String] = []
    public private(set) var foundAppProduct: Bool = false
    public private(set) var foundOrientationsArgument: Bool = false

    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
              memberAccess.declName.baseName.text == "iOSApplication" else {
            return .visitChildren
        }

        // We only parse the first one we find.
        guard !foundAppProduct else { return .skipChildren }
        foundAppProduct = true

        let args = node.arguments
        for arg in args where arg.label?.text == "supportedInterfaceOrientations" {
            foundOrientationsArgument = true
            
            if let arrayExpr = arg.expression.as(ArrayExprSyntax.self) {
                for element in arrayExpr.elements {
                    orientations.append(element.expression.description.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        return .skipChildren
    }
}

// MARK: - Rewriter (Add / Remove)

public enum OrientationMutation: Sendable {
    case add(String)
    case remove(String)
}

/// A `SyntaxRewriter` that mutates the `supportedInterfaceOrientations` array
/// inside the first `.iOSApplication(...)` product call.
public final class OrientationRewriter: SyntaxRewriter {
    public let mutation: OrientationMutation
    
    public private(set) var foundAppProduct = false
    public private(set) var foundOrientationsArgument = false
    
    public init(mutation: OrientationMutation) {
        self.mutation = mutation
    }

    public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
              memberAccess.declName.baseName.text == "iOSApplication" else {
            return super.visit(node)
        }

        guard !foundAppProduct else { return super.visit(node) }
        foundAppProduct = true

        let args = node.arguments
        
        var hasOrientationsArg = false
        let updatedArgs = LabeledExprListSyntax(args.map { arg -> LabeledExprSyntax in
            guard arg.label?.text == "supportedInterfaceOrientations" else { return arg }
            hasOrientationsArg = true
            foundOrientationsArgument = true
            
            let patchedArray = rewriteOrientationArray(arg.expression)
            return arg.with(\.expression, patchedArray)
        })
        
        // If it was not found, we insert a fresh argument
        if !hasOrientationsArg {
            // Note: We only insert it if we're adding. If we're removing, we ignore.
            if case .add = mutation {
                let insertedArgs = insertOrientationsArgument(into: args)
                return ExprSyntax(node.with(\.arguments, insertedArgs))
            } else {
                return super.visit(node)
            }
        }

        return ExprSyntax(node.with(\.arguments, updatedArgs))
    }

    // MARK: - Array Mutation

    private func rewriteOrientationArray(_ expr: ExprSyntax) -> ExprSyntax {
        guard let arrayExpr = expr.as(ArrayExprSyntax.self) else { return expr }

        switch mutation {
        case .add(let targetName):
            let targetBaseName = extractBaseName(from: targetName)
            // Check if already present
            let isPresent = arrayExpr.elements.contains { element in
                extractBaseName(from: element.expression) == targetBaseName
            }
            if isPresent { return expr } // No modification needed
            
            let newElementExpr = makeOrientationElement(for: targetName)
            var elements = Array(arrayExpr.elements)
            
            // Fix trailing comma mapping
            if !elements.isEmpty {
                let lastIndex = elements.count - 1
                if elements[lastIndex].trailingComma == nil {
                    elements[lastIndex] = elements[lastIndex].with(\.trailingComma, .commaToken())
                }
            }
            
            let trivia = elements.last?.leadingTrivia ?? .newline
            let newElement = ArrayElementSyntax(
                leadingTrivia: trivia,
                expression: newElementExpr,
                trailingComma: nil
            )
            
            elements.append(newElement)
            return ExprSyntax(arrayExpr.with(\.elements, ArrayElementListSyntax(elements)))

        case .remove(let targetName):
            let targetBaseName = extractBaseName(from: targetName)
            var remainingElements = arrayExpr.elements.filter { element in
                extractBaseName(from: element.expression) != targetBaseName
            }
            
            // Filter might have removed the last element but left a trailing comma on the new last element.
            if let last = remainingElements.last {
                // Actually SwiftSyntax arrays format fine with trailing commas usually,
                // but we strip the trailing comma from the *absolute last* element just in case.
                let lastIndex = remainingElements.index(before: remainingElements.endIndex)
                remainingElements[lastIndex] = last.with(\.trailingComma, nil)
            }
            
            return ExprSyntax(arrayExpr.with(\.elements, ArrayElementListSyntax(remainingElements)))
        }
    }

    private func extractBaseName(from expr: ExprSyntax) -> String? {
        if let callExpr = expr.as(FunctionCallExprSyntax.self),
           let memberExpr = callExpr.calledExpression.as(MemberAccessExprSyntax.self) {
            return memberExpr.declName.baseName.text
        } else if let memberExpr = expr.as(MemberAccessExprSyntax.self) {
            return memberExpr.declName.baseName.text
        }
        return nil
    }

    private func extractBaseName(from string: String) -> String {
        if let parenIndex = string.firstIndex(of: "(") {
            return String(string[..<parenIndex])
        }
        return string
    }

    private func makeOrientationElement(for name: String) -> ExprSyntax {
        let source = ".\(name)"
        return Parser.parse(source: source).statements.first!.item.as(ExprSyntax.self)!
    }
    
    private func insertOrientationsArgument(into args: LabeledExprListSyntax) -> LabeledExprListSyntax {
        guard case .add(let targetName) = mutation else { return args }

        var result = Array(args)
        let elementExpr = makeOrientationElement(for: targetName)
        let src = "supportedInterfaceOrientations: [\(elementExpr.description)]"
        
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

// MARK: - Convenience Entry Points

public extension PackageSwiftFile {
    /// Gets the current list of `supportedInterfaceOrientations` as strings.
    func getOrientations() async throws -> [String] {
        let syntaxToRead = self.syntax
        
        return await Task {
            let visitor = GetOrientationsVisitor(viewMode: .sourceAccurate)
            visitor.walk(syntaxToRead)
            return visitor.orientations
        }.value
    }

    /// Mutates the `supportedInterfaceOrientations` array.
    mutating func applyOrientationMutation(_ mutation: OrientationMutation) async throws {
        let syntaxToRewrite = self.syntax
        
        let result = await Task {
            let rewriter = OrientationRewriter(mutation: mutation)
            let rewritten = rewriter.visit(syntaxToRewrite)
            return (
                foundApp: rewriter.foundAppProduct,
                foundArg: rewriter.foundOrientationsArgument,
                rewritten: rewritten
            )
        }.value

        if !result.foundApp {
            throw OrientationEditorError.applicationProductNotFound
        }
        // It's ok if foundArg is false if we are adding, because we just insert the argument.
        // If we are removing and it isn't there, it's a silent no-op or error, we'll no-op.

        apply(rewritten: result.rewritten)
    }
    
    mutating func addOrientation(_ orientation: String) async throws {
        try await applyOrientationMutation(.add(orientation))
    }

    mutating func removeOrientation(_ orientation: String) async throws {
        try await applyOrientationMutation(.remove(orientation))
    }
}
