import Foundation
import SwiftSyntax
import SwiftParser

public struct AppInfo: Sendable, Equatable {
    public var name: String?
    public var id: String?
    public var teamIdentifier: String?
    public var displayVersion: String?
    public var bundleVersion: String?
    public var iconAssetName: String?
    public var accentColorAssetName: String?
    public var hasInfoPlist: Bool = false
    
    public init() {}
}

/// A `SyntaxVisitor` that extracts basic app information from the
/// first `.iOSApplication(…)` or `.macOSApplication(…)` product call in `Package.swift`.
public final class AppInfoReaderVisitor: SyntaxVisitor {
    public private(set) var appInfo = AppInfo()
    public private(set) var foundAppProduct: Bool = false

    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
              (memberAccess.declName.baseName.text == "iOSApplication" || memberAccess.declName.baseName.text == "macOSApplication") else {
            return .visitChildren
        }

        guard !foundAppProduct else { return .skipChildren }
        foundAppProduct = true

        let args = node.arguments
        for arg in args {
            switch arg.label?.text {
            case "name":
                appInfo.name = arg.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
            case "id", "bundleIdentifier":
                appInfo.id = arg.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
            case "teamIdentifier":
                appInfo.teamIdentifier = arg.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
            case "displayVersion", "version":
                appInfo.displayVersion = arg.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
            case "bundleVersion", "buildNumber":
                appInfo.bundleVersion = arg.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
            case "appIcon":
                if let callExpr = arg.expression.as(FunctionCallExprSyntax.self),
                   let memberAccess = callExpr.calledExpression.as(MemberAccessExprSyntax.self),
                   memberAccess.declName.baseName.text == "asset" {
                    appInfo.iconAssetName = callExpr.arguments.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
                }
            case "accentColor":
                if let callExpr = arg.expression.as(FunctionCallExprSyntax.self),
                   let memberAccess = callExpr.calledExpression.as(MemberAccessExprSyntax.self),
                   memberAccess.declName.baseName.text == "asset" {
                    appInfo.accentColorAssetName = callExpr.arguments.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
                }
            case "additionalInfoPlistContentFilePath", "infoPlist":
                appInfo.hasInfoPlist = true
            default:
                break
            }
        }
        
        return .skipChildren
    }
}

public extension PackageSwiftFile {
    /// Gets the current App Info for the executable product.
    func getAppInfo() async throws -> AppInfo {
        let syntaxToRead = self.syntax
        return await Task {
            let visitor = AppInfoReaderVisitor(viewMode: .sourceAccurate)
            visitor.walk(syntaxToRead)
            return visitor.appInfo
        }.value
    }
}
