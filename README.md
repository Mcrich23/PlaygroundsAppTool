# PlaygroundsAppTool

PlaygroundsAppTool is a powerful CLI/UI App utility for managing and configuring Swift Playground App (`.swiftpm`) projects. It helps you quickly adjust your app's capabilities, assets, and requirements without having to manually edit configuration files.

## Usage

```bash
PlaygroundsAppTool <subcommand>
```

All commands support a `--project <path>` option to specify the path to your `.swiftpm` directory. By default, this is `./`.

### Global Options
- `--project <path>`: The path to the `.swiftpm` project. Defaults to `./`.
- `--target <name>`: The name of your app's main target. Defaults to `AppModule`.

---

## Commands

### Versions (`versions`)

Control the minimum iOS version and Swift language version your app requires.

- **Set Minimum iOS Version**
  Updates your app to require a specific minimum iOS version.
  ```bash
  PlaygroundsAppTool versions iOS <version>
  # Example: PlaygroundsAppTool versions iOS 17.0
  ```

- **Set Swift Language Version**
  Sets the Swift language compiler version for your project (valid options: 5 or 6).
  ```bash
  PlaygroundsAppTool versions swift <version>
  # Example: PlaygroundsAppTool versions swift 6
  ```

### App Assets & Resources (`resources`)

Manage the files bundled with your app, such as images, audio clips, JSON data, and custom fonts.

- **Initialize Resources**
  Creates a `Resources` directory and links it to your app. Any files you drop into this directory will be bundled with your app when it builds.
  ```bash
  PlaygroundsAppTool resources init
  ```

- **Remove Resources**
  Unlinks the `Resources` directory, meaning assets will no longer be bundled.
  ```bash
  PlaygroundsAppTool resources remove
  ```

### Advanced App Capabilities (`info-plist`)

By default, Swift Playgrounds apps operate within a restricted sandbox. Adding an `Info.plist` file lets you request permissions (like Camera, Microphone, or Location access) and configure advanced app behaviors.

- **Initialize Info.plist**
  Generates an `Info.plist` file and links it to your app, allowing you to bypass typical sandbox restrictions by configuring custom XML keys.
  ```bash
  PlaygroundsAppTool info-plist init
  ```

- **Remove Info.plist**
  Unlinks the `Info.plist` file from your app, reverting it to standard Playground restrictions.
  ```bash
  PlaygroundsAppTool info-plist remove
  ```

### Interface Orientations (`orientation`)

Control how your app behaves when the user rotates their iPhone or iPad. You can lock your app to portrait mode or allow it to flexibly rotate into landscape.

- **List Allowed Orientations**
  Shows all the device orientations your app currently supports.
  ```bash
  PlaygroundsAppTool orientation list
  ```

- **Allow an Orientation**
  Enables your app to rotate into a specific orientation (`portrait`, `landscapeLeft`, `landscapeRight`, `portraitUpsideDown`).
  ```bash
  PlaygroundsAppTool orientation add <orientation>
  # Example: PlaygroundsAppTool orientation add landscapeRight
  ```

- **Restrict an Orientation**
  Prevents your app from rotating into a specific orientation.
  ```bash
  PlaygroundsAppTool orientation remove <orientation>
  ```

### General App Information (`appInfo`)

Retrieve and modify broader configuration metadata like category, accent colors, and supported hardware.

- **Check Current App Info**
  Displays out the currently active settings in the manifest.
  ```bash
  PlaygroundsAppTool appInfo get
  ```

- **Update the App Source Category**
  Sets the main App Store category (e.g. `games`, `education`, `productivity`).
  ```bash
  PlaygroundsAppTool appInfo setCategory <category>
  # Example: PlaygroundsAppTool appInfo setCategory actionGames
  ```

- **Update Accent Color**
  Change the universal accent highlight color. You can supply either an Asset Catalog name or use an Apple generic UI color preset.
  ```bash
  PlaygroundsAppTool appInfo setAccentColor --preset <preset>
  # Example: PlaygroundsAppTool appInfo setAccentColor --preset blue
  PlaygroundsAppTool appInfo setAccentColor --asset <assetName>
  # Example: PlaygroundsAppTool appInfo setAccentColor --asset CustomRed
  ```

- **Set Supported Devices**
  Toggles which Apple device platforms the application can legally be installed on. Options include `phone`, `pad`.
  ```bash
  PlaygroundsAppTool appInfo setDeviceFamilies <family1> <family2> ...
  # Example: PlaygroundsAppTool appInfo setDeviceFamilies phone pad
  ```
