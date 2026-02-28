# PlaygroundsAppTool

PlaygroundsAppTool is a powerful CLI utility for programmatically managing and modifying Swift Playground App (`.swiftpm`) projects. It uses `swift-syntax` to read, manipulate, and rewrite `Package.swift` ASTs with perfect whitespace preservation.

## Usage

```bash
PlaygroundsAppTool <subcommand>
```

All commands support a `--project <path>` option to specify the path to your `.swiftpm` directory. By default, this is `./`.

### Global Options
- `--project <path>`: The path to the `.swiftpm` project. Defaults to `./`.
- `--target <name>`: The name of the target inside `Package.swift` (mostly used for `resources`). Defaults to `AppModule`.

---

## Commands

### Platform Requirements

Manage the target platforms required for your Playground App.

- **Set a Platform Version**
  Sets the minimum OS version for a specific platform. If the platform doesn't exist in the array, it will be added.
  ```bash
  PlaygroundsAppTool platform set <platform> <version>
  # Example: PlaygroundsAppTool platform set iOS 17.0
  ```

- **Remove a Platform**
  Removes a platform entirely from the `platforms` array.
  ```bash
  PlaygroundsAppTool platform remove <platform>
  # Example: PlaygroundsAppTool platform remove visionOS
  ```

### Swift Language Version

Manage the `swiftLanguageVersions` array and `// swift-tools-version:` comment at the top of the `Package.swift`.

- **Set Swift Version**
  Sets the language version and updates the `// swift-tools-version:` comment.
  ```bash
  PlaygroundsAppTool swift-version set <version>
  # Example: PlaygroundsAppTool swift-version set 6.0
  ```

- **Remove Swift Version**
  Removes the `swiftLanguageVersions` property entirely from the root `Package` declaration.
  ```bash
  PlaygroundsAppTool swift-version remove
  ```

### Resources

Easily link a `Resources` folder to your target.

- **Init Resources**
  Creates a physical `Resources` directory and injects `resources: [.process("Resources")]` into your executable target.
  ```bash
  PlaygroundsAppTool resources init
  # Example: PlaygroundsAppTool resources init
  ```

- **Remove Resources**
  Removes the `resources` property from your target configuration.
  ```bash
  PlaygroundsAppTool resources remove
  ```

### Info.plist

Link custom `.plist` files to bypass typical Playground sandboxing or provide additional App capabilities.

- **Init Info.plist**
  Creates an empty `Info.plist` file physically on disk and injects the `additionalInfoPlistContentFilePath: "Info.plist"` property into the `.iOSApplication` product.
  ```bash
  PlaygroundsAppTool info-plist init
  ```

- **Remove Info.plist**
  Removes the `additionalInfoPlistContentFilePath` property from the application product.
  ```bash
  PlaygroundsAppTool info-plist remove
  ```

### Orientations

Manage the `supportedInterfaceOrientations` array in your iOS Application product.

- **List Orientations**
  Lists all actively configured interface orientations.
  ```bash
  PlaygroundsAppTool orientation list
  ```

- **Add Orientation**
  Adds a new orientation to the array (e.g. `portrait`, `landscapeLeft`, `landscapeRight`, `portraitUpsideDown`).
  ```bash
  PlaygroundsAppTool orientation add <orientation>
  # Example: PlaygroundsAppTool orientation add landscapeRight
  ```

- **Remove Orientation**
  Removes an orientation from the array.
  ```bash
  PlaygroundsAppTool orientation remove <orientation>
  ```
