import SwiftUI
import UniformTypeIdentifiers
import PlaygroundsAppToolLibrary

struct ContentView: View {
    @State private var model = PackageModel()
    @State private var isShowingFileImporter = false

    var body: some View {
        NavigationSplitView {
            List {
                if model.isLoaded {
                    Section(model.packageFile?.url.deletingLastPathComponent().lastPathComponent ?? "Project Details") {
                        NavigationLink(destination: BasicInfoView(model: model)) {
                            Label("Basic Info", systemImage: "info.circle")
                        }
                        NavigationLink(destination: PlatformView(model: model)) {
                            Label("Versions", systemImage: "applelogo")
                        }
                        NavigationLink(destination: OrientationView(model: model)) {
                            Label("Orientations", systemImage: "arrow.triangle.2.circlepath")
                        }
                        NavigationLink(destination: CapabilitiesView(model: model)) {
                            Label("Capabilities", systemImage: "slider.horizontal.3")
                        }
                    }
                } else {
                    Text("Select a project to begin")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("PlaygroundsAppTool")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        isShowingFileImporter = true
                    }) {
                        Label("Open Project", systemImage: "folder")
                    }
                }
            }
        } detail: {
            if model.isLoaded {
                VStack(spacing: 20) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Select a section from the sidebar to configure your app.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "swift")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    Text("PlaygroundsAppTool")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Manage Swift Playgrounds Projects")
                        .foregroundStyle(.secondary)
                    
                    Button("Open Project") {
                        isShowingFileImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    if let error = model.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.directory, .package],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await model.load(from: url)
                    }
                }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
