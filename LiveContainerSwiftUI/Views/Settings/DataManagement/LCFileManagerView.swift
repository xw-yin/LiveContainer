import SwiftUI
import UIKit
import QuickLook

private struct LCFileRoot: Identifiable, Sendable {
    let title: String
    let url: URL
    var id: String { url.path }

    static var locations: [LCFileRoot] {
        var roots = [
            LCFileRoot(title: "lc.fileManager.documents".loc, url: LCPath.docPath),
            LCFileRoot(title: "lc.fileManager.library".loc,
                       url: LCPath.docPath.deletingLastPathComponent().appendingPathComponent("Library")),
            LCFileRoot(title: "lc.fileManager.temporary".loc, url: FileManager.default.temporaryDirectory)
        ]
        if let group = LCSharedUtils.appGroupPath() {
            roots.append(LCFileRoot(title: "lc.fileManager.appGroup".loc, url: group))
        }
        return roots
    }
}

struct LCFileManagerView: View {
    var body: some View {
        List(LCFileRoot.locations) { root in
            NavigationLink {
                LCFileBrowserView(root: root, directory: root.url)
            } label: {
                Label(root.title, systemImage: "folder")
            }
        }
        .navigationTitle("lc.fileManager.title".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LCFileBrowserView: View {
    let root: LCFileRoot
    let directory: URL
    @EnvironmentObject private var sharedModel: SharedModel
    @State private var entries: [LCFileEntry] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var isDeleting = false
    @State private var deletionCandidate: LCFileEntry?
    @State private var errorMessage: String?
    @State private var presentation: LCFilePresentation?

    private var filteredEntries: [LCFileEntry] {
        search.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            Section {
                ForEach(filteredEntries) { entry in
                    fileRow(entry)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = entry.url.path
                            } label: {
                                Label("lc.fileManager.copyPath".loc, systemImage: "doc.on.doc")
                            }
                            if !entry.isDirectory && !entry.isSymbolicLink {
                                Button {
                                    open(entry, sharing: true)
                                } label: {
                                    Label("lc.fileManager.share".loc, systemImage: "square.and.arrow.up")
                                }
                            }
                            Button(role: .destructive) {
                                deletionCandidate = entry
                            } label: {
                                Label("lc.common.delete".loc, systemImage: "trash")
                            }
                        }
                        .swipeActions(allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletionCandidate = entry
                            } label: {
                                Label("lc.common.delete".loc, systemImage: "trash")
                            }
                        }
                }
                if filteredEntries.isEmpty && !isLoading {
                    Text("lc.fileManager.empty".loc).foregroundStyle(.secondary)
                }
            } footer: {
                Text(directory.path).font(.caption).textSelection(.enabled)
            }
        }
        .disabled(isDeleting)
        .searchable(text: $search, prompt: "lc.fileManager.search".loc)
        .navigationTitle(directory == root.url ? root.title : directory.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading || isDeleting { ProgressView() }
        }
        .toolbar {
            Button {
                Task { await reload() }
            } label: {
                Label("lc.fileManager.refresh".loc, systemImage: "arrow.clockwise")
            }
            .disabled(isLoading || isDeleting)
        }
        .task { await reload() }
        .refreshable { await reload() }
        .confirmationDialog("lc.common.delete".loc, isPresented: Binding(
            get: { deletionCandidate != nil },
            set: { if !$0 { deletionCandidate = nil } }
        ), titleVisibility: .visible, presenting: deletionCandidate) { entry in
            Button("lc.common.delete".loc, role: .destructive) {
                Task { await delete(entry) }
            }
        } message: { entry in
            Text("lc.fileManager.deleteConfirm %@".localizeWithFormat(entry.name))
        }
        .alert("lc.common.error".loc, isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("lc.common.ok".loc, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $presentation) { item in
            switch item {
            case .preview(let url): LCFilePreview(url: url)
            case .share(let url): ActivityViewController(activityItems: [url])
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ entry: LCFileEntry) -> some View {
        if entry.isDirectory {
            NavigationLink {
                LCFileBrowserView(root: root, directory: entry.url)
            } label: {
                entryLabel(entry)
            }
        } else {
            Button {
                if entry.isSymbolicLink {
                    // Links can be inspected/copied/deleted, but never followed.
                    do {
                        let target = try FileManager.default.destinationOfSymbolicLink(atPath: entry.url.path)
                        UIPasteboard.general.string = target
                    } catch { errorMessage = error.localizedDescription }
                } else {
                    open(entry, sharing: false)
                }
            } label: {
                entryLabel(entry)
            }
            .buttonStyle(.plain)
        }
    }

    private func entryLabel(_ entry: LCFileEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.isSymbolicLink ? "link" : entry.isDirectory ? "folder" : "doc")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name).foregroundStyle(.primary)
                if entry.isSymbolicLink {
                    Text("lc.fileManager.symbolicLink".loc).font(.caption).foregroundStyle(.secondary)
                } else if !entry.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @MainActor
    private func reload() async {
        guard !isLoading && !isDeleting else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Task.detached(priority: .utility) { [directory, root] in
                try LCFileBrowser.load(directory: directory, root: root.url)
            }.value
            guard !Task.isCancelled else { return }
            entries = result
        } catch {
            guard !Task.isCancelled else { return }
            entries = []
            errorMessage = error.localizedDescription + "\n" + directory.path
        }
    }

    @MainActor
    private func open(_ entry: LCFileEntry, sharing: Bool) {
        do {
            try LCFileBrowser.validate(entry.url, in: root.url)
            let values = try FileManager.default.attributesOfItem(atPath: entry.url.path)
            guard values[.type] as? FileAttributeType == .typeRegular else {
                throw CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: entry.url.path])
            }
            if sharing {
                presentation = .share(entry.url)
            } else if QLPreviewController.canPreview(entry.url as NSURL) {
                presentation = .preview(entry.url)
            } else {
                presentation = .share(entry.url)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func delete(_ entry: LCFileEntry) async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            // Do not remove an active container or one of its ancestors/files.
            for app in sharedModel.apps + sharedModel.hiddenApps {
                for container in app.uiContainers {
                    if let usingLC = LCSharedUtils.getContainerUsingLCScheme(withFolderName: container.folderName) {
                        let target = entry.isSymbolicLink
                            ? entry.url.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(entry.name)
                            : entry.url.resolvingSymlinksInPath()
                        let data = container.containerURL.resolvingSymlinksInPath()
                        if LCFileBrowser.contains(target, in: data) || LCFileBrowser.contains(data, in: target) {
                            throw "lc.container.inUseBy %@".localizeWithFormat(usingLC)
                        }
                    }
                }
            }
            try await Task.detached(priority: .utility) { [root] in
                if let url = try LCFileBrowser.deletionURL(for: entry, root: root.url) {
                    try FileManager.default.removeItemUnlocking(at: url)
                }
            }.value
        } catch {
            errorMessage = error.localizedDescription
        }
        // A failed recursive removal can still have deleted some children.
        do {
            entries = try await Task.detached(priority: .utility) { [directory, root] in
                try LCFileBrowser.load(directory: directory, root: root.url)
            }.value
        } catch {
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }
        if let folders = try? LCFileBrowser.load(directory: LCPath.dataPath, root: LCPath.dataPath) {
            sharedModel.appDataFolderNames = folders.filter { $0.isDirectory || $0.isSymbolicLink }.map(\.name)
        } else if !FileManager.default.fileExists(atPath: LCPath.dataPath.path) {
            sharedModel.appDataFolderNames = []
        }
    }
}

private enum LCFilePresentation: Identifiable {
    case preview(URL)
    case share(URL)
    var id: String {
        switch self {
        case .preview(let url): "preview:\(url.path)"
        case .share(let url): "share:\(url.path)"
        }
    }
}

private struct LCFilePreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
