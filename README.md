# PlaygroundsAppTool

PlaygroundsAppTool is a powerful CLI utility for managing and configuring Swift Playground App (`.swiftpm`) projects. It helps you quickly adjust your app's capabilities, assets, and requirements without having to manually edit configuration files.

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

### Platform Requirements (`platform`)

Control which Apple operating systems and versions your app supports. Updating these allows you to drop support for older iOS versions, adopt the newest SwiftUI APIs, or add support for platforms like macOS or visionOS. 

- **Set Minimum OS Version**
  Updates your app to require a specific OS version.
  ```bash
  PlaygroundsAppTool platform set <platform> <version>
  # Example: PlaygroundsAppTool platform set iOS 17.0
  ```

- **Drop Platform Support**
  Removes a platform entirely, meaning your app will no longer run on it.
  ```bash
  PlaygroundsAppTool platform remove <platform>
  # Example: PlaygroundsAppTool platform remove visionOS
  ```

### Swift Language Version (`swift-version`)

Keep your project up-to-date with the latest Swift language features.

- **Set Swift Version**
  Sets your app to use whatever Swift compiler version you want.
  ```bash
  PlaygroundsAppTool swift-version set <version>
  # Example: PlaygroundsAppTool swift-version set 6.0
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
