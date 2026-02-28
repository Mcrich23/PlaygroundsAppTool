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
            
            Section(header: Text("Appearance & Category")) {
                let appCategories = [
                    ("None", ""),
                    ("Books", "books"),
                    ("Business", "business"),
                    ("Developer Tools", "developerTools"),
                    ("Education", "education"),
                    ("Entertainment", "entertainment"),
                    ("Finance", "finance"),
                    ("Food & Drink", "foodAndDrink"),
                    ("Games", "games"),
                    ("Games - Action Games", "actionGames"),
                    ("Games - Adventure Games", "adventureGames"),
                    ("Games - Board Games", "boardGames"),
                    ("Games - Card Games", "cardGames"),
                    ("Games - Casino Games", "casinoGames"),
                    ("Games - Casual Games", "casualGames"),
                    ("Games - Family Games", "familyGames"),
                    ("Games - Kids Games", "kidsGames"),
                    ("Games - Music Games", "musicGames"),
                    ("Games - Puzzle Games", "puzzleGames"),
                    ("Games - Racing Games", "racingGames"),
                    ("Games - Role Playing Games", "rolePlayingGames"),
                    ("Games - Simulation Games", "simulationGames"),
                    ("Games - Sports Games", "sportsGames"),
                    ("Games - Strategy Games", "strategyGames"),
                    ("Games - Trivia Games", "triviaGames"),
                    ("Games - Word Games", "wordGames"),
                    ("Graphics & Design", "graphicsAndDesign"),
                    ("Health & Fitness", "healthAndFitness"),
                    ("Lifestyle", "lifestyle"),
                    ("Magazines & Newspapers", "magazinesAndNewspapers"),
                    ("Medical", "medical"),
                    ("Music", "music"),
                    ("Navigation", "navigation"),
                    ("News", "news"),
                    ("Photography", "photography"),
                    ("Productivity", "productivity"),
                    ("Reference", "reference"),
                    ("Shopping", "shopping"),
                    ("Social Networking", "socialNetworking"),
                    ("Sports", "sports"),
                    ("Travel", "travel"),
                    ("Utilities", "utilities"),
                    ("Video", "video"),
                    ("Weather", "weather")
                ]
                
                Picker("App Category", selection: Binding(
                    get: { model.appInfo.appCategory ?? "" },
                    set: { model.appInfo.appCategory = $0.isEmpty ? nil : $0 }
                )) {
                    ForEach(appCategories, id: \.1) { (label, value) in
                        Text(label).tag(value)
                    }
                }
                
                Picker("Accent Color Type", selection: Binding(
                    get: {
                        if let color = model.appInfo.accentColor {
                            if case .presetColor = color { return "Preset" }
                        }
                        return "Asset"
                    },
                    set: { newType in
                        if newType == "Asset" {
                            model.appInfo.accentColor = .asset("AccentColor")
                        } else if newType == "Preset" {
                            model.appInfo.accentColor = .presetColor("blue")
                        }
                    }
                )) {
                    Text("Asset Name").tag("Asset")
                    Text("Preset Color").tag("Preset")
                }
                
                if let color = model.appInfo.accentColor {
                    if case .asset(let name) = color {
                        TextField("Asset Name", text: Binding(
                            get: { name },
                            set: { model.appInfo.accentColor = .asset($0) }
                        ))
                    } else if case .presetColor(let name) = color {
                        let presetColors = [
                            ("Red", "red"),
                            ("Orange", "orange"),
                            ("Yellow", "yellow"),
                            ("Green", "green"),
                            ("Mint", "mint"),
                            ("Teal", "teal"),
                            ("Cyan", "cyan"),
                            ("Blue", "blue"),
                            ("Indigo", "indigo"),
                            ("Purple", "purple"),
                            ("Pink", "pink"),
                            ("Brown", "brown")
                        ]
                        
                        Picker("Preset Color", selection: Binding(
                            get: { name },
                            set: { model.appInfo.accentColor = .presetColor($0) }
                        )) {
                            ForEach(presetColors, id: \.1) { (label, value) in
                                HStack {
                                    // A simple circle to roughly approximate the color in UI
                                    Circle()
                                        .fill(colorForPreset(value))
                                        .frame(width: 12, height: 12)
                                    Text(label)
                                }.tag(value)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Supported Device Families")) {
                let families = ["phone", "pad"]
                ForEach(families, id: \.self) { family in
                    Toggle(family.capitalized, isOn: Binding(
                        get: { model.appInfo.supportedDeviceFamilies.contains(family) },
                        set: { isEnabled in
                            if isEnabled {
                                if !model.appInfo.supportedDeviceFamilies.contains(family) {
                                    model.appInfo.supportedDeviceFamilies.append(family)
                                }
                            } else {
                                model.appInfo.supportedDeviceFamilies.removeAll { $0 == family }
                            }
                        }
                    ))
                }
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
                        } else {
                            Text(platform.rawValue)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Add") {
                                Task {
                                    let defaultVersion = "26.0"
                                    await model.setPlatform(platform, version: defaultVersion)
                                }
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Swift Language Version")) {
                Picker("Swift Version", selection: Binding(
                    get: { model.swiftVersion.isEmpty ? "6" : model.swiftVersion },
                    set: { newValue in
                        model.swiftVersion = newValue
                        Task {
                            await model.saveSwiftVersion(newValue)
                        }
                    }
                )) {
                    Text("Swift 5").tag("5")
                    Text("Swift 6").tag("6")
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Versions")
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
    
    func formattedOrientationName(_ name: String) -> String {
        guard let first = name.first, !name.isEmpty else {
            return name
        }
        
        return String(first).capitalized + name.dropFirst()
    }
    
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
                    
                    Toggle(formattedOrientationName(orientation) + conditionLabel, isOn: Binding(
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

// MARK: - Helpers

func colorForPreset(_ name: String) -> Color {
    switch name {
    case "red": return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "green": return .green
    case "mint": return .mint
    case "teal": return .teal
    case "cyan": return .cyan
    case "blue": return .blue
    case "indigo": return .indigo
    case "purple": return .purple
    case "pink": return .pink
    case "brown": return .brown
    default: return .clear
    }
}
