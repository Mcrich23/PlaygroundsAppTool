import SwiftUI
import PlaygroundsAppToolLibrary

// MARK: - Basic Info View

struct BasicInfoView: View {
    @Bindable var model: PackageModel
    
    var body: some View {
        Form {
            Section(header: Text("Application Information")) {
                TextField("App Name", text: Binding(
                    get: { model.appInfo.name ?? "" },
                    set: { model.appInfo.name = $0.isEmpty ? nil : $0 }
                ))
                TextField("Bundle Identifier", text: Binding(
                    get: { model.appInfo.id ?? "" },
                    set: { model.appInfo.id = $0.isEmpty ? nil : $0 }
                ))
                TextField("Team Identifier", text: Binding(
                    get: { model.appInfo.teamIdentifier ?? "" },
                    set: { model.appInfo.teamIdentifier = $0.isEmpty ? nil : $0 }
                ))
            }
            
            Section(header: Text("Versioning")) {
                TextField("Display Version", text: Binding(
                    get: { model.appInfo.displayVersion ?? "" },
                    set: { model.appInfo.displayVersion = $0.isEmpty ? nil : $0 }
                ))
                TextField("Bundle Version", text: Binding(
                    get: { model.appInfo.bundleVersion ?? "" },
                    set: { model.appInfo.bundleVersion = $0.isEmpty ? nil : $0 }
                ))
            }
            
            if let error = model.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
            
            Button("Save Changes") {
                Task {
                    await model.saveAppInfo()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .formStyle(.grouped)
        .navigationTitle("Basic Info")
    }
}

// MARK: - Platform View

struct PlatformView: View {
    @Bindable var model: PackageModel
    
    var body: some View {
        Form {
            Section(header: Text("Supported Platforms"), footer: Text("Add or update the minimum requested platform versions.")) {
                ForEach(PackagePlatform.allCases, id: \.self) { platform in
                    HStack {
                        if let version = model.platforms[platform] {
                            Text(platform.rawValue)
                            Spacer()
                            TextField("Version", text: Binding(
                                get: { version },
                                set: { newValue in
                                    Task { await model.setPlatform(platform, version: newValue) }
                                }
                            ))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            
                            Button(role: .destructive) {
                                Task { await model.removePlatform(platform) }
                            } label: {
                                Image(systemName: "trash")
                            }
                        } else {
                            Text(platform.rawValue)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Add") {
                                Task {
                                    // Default minimal version, can easily be changed later
                                    let defaultVersion = platform == .iOS ? "16.0" : "1.0"
                                    await model.setPlatform(platform, version: defaultVersion)
                                }
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Swift Language Version")) {
                TextField("Swift Version", text: $model.swiftVersion)
                    .onSubmit {
                        Task {
                            await model.saveSwiftVersion(model.swiftVersion)
                        }
                    }
                Button("Update Swift Version") {
                    Task {
                        await model.saveSwiftVersion(model.swiftVersion)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Platforms")
    }
}

// MARK: - Orientation View

struct OrientationView: View {
    @Bindable var model: PackageModel
    
    let allOrientations = [
        "portrait",
        "portraitUpsideDown",
        "landscapeLeft",
        "landscapeRight"
    ]
    
    var body: some View {
        Form {
            Section(header: Text("Supported Interface Orientations")) {
                ForEach(allOrientations, id: \.self) { orientation in
                    let searchStr = ".\(orientation)"
                    let match = model.orientations.first(where: { $0 == searchStr || $0.hasPrefix(searchStr + "(") })
                    let isEnabled = match != nil
                    
                    let conditionLabel: String = if let m = match, m.contains(".when(deviceFamilies: [.pad])") {
                        " (Pad Only)"
                    } else if let m = match, m.contains(".when(deviceFamilies: [.phone])") {
                        " (Phone Only)"
                    } else if let m = match, m.contains(".when(") {
                        " (Custom)"
                    } else {
                        ""
                    }
                    
                    let isAlways = isEnabled && conditionLabel == ""
                    let isPadOnly = isEnabled && conditionLabel == " (Pad Only)"
                    let isPhoneOnly = isEnabled && conditionLabel == " (Phone Only)"
                    
                    Toggle(orientation.capitalized + conditionLabel, isOn: Binding(
                        get: { isEnabled },
                        set: { _ in
                            Task {
                                await model.toggleOrientation(orientation)
                            }
                        }
                    ))
                    .contextMenu {
                        Button {
                            Task { await model.setOrientationCondition(orientation, condition: nil) }
                        } label: {
                            Text("Always")
                            if isAlways { Image(systemName: "checkmark") }
                        }
                        Button {
                            Task { await model.setOrientationCondition(orientation, condition: ".when(deviceFamilies: [.pad])") }
                        } label: {
                            Text("Pad Only")
                            if isPadOnly { Image(systemName: "checkmark") }
                        }
                        Button {
                            Task { await model.setOrientationCondition(orientation, condition: ".when(deviceFamilies: [.phone])") }
                        } label: {
                            Text("Phone Only")
                            if isPhoneOnly { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            if let error = model.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Orientations")
    }
}

// MARK: - Capabilities View

struct CapabilitiesView: View {
    @Bindable var model: PackageModel
    
    var body: some View {
        Form {
            Section(header: Text("App Resources"), footer: Text("Allows bundling images, audio, and other custom files.")) {
                Toggle("Include Resources Folder", isOn: Binding(
                    get: { model.hasResources },
                    set: { _ in
                        Task { await model.toggleResources() }
                    }
                ))
            }
            
            Section(header: Text("Sandbox Capabilities"), footer: Text("Use an Info.plist to request special sandbox exceptions (e.g. Camera access).")) {
                Toggle("Custom Info.plist", isOn: Binding(
                    get: { model.appInfo.hasInfoPlist },
                    set: { _ in
                        Task { await model.toggleInfoPlist() }
                    }
                ))
            }
            
            if let error = model.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Capabilities")
    }
}
