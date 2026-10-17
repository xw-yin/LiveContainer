import Foundation

struct LCFileEntry: Identifiable, Sendable {
    let url: URL
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let size: Int64
    let fileNumber: UInt64
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

// Filesystem work runs off the UI thread. Root checks use path components,
// not a string prefix that would also accept a sibling such as Documents-old.
enum LCFileBrowser {
    static func contains(_ item: URL, in root: URL) -> Bool {
        let rootParts = root.standardizedFileURL.pathComponents
        return item.standardizedFileURL.pathComponents.starts(with: rootParts)
    }

    static func validate(_ url: URL, in root: URL) throws {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let canonicalParent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let candidate = canonicalParent.appendingPathComponent(url.lastPathComponent).standardizedFileURL
        guard contains(candidate, in: canonicalRoot), candidate.pathComponents != canonicalRoot.pathComponents else {
            throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    static func load(directory: URL, root: URL) throws -> [LCFileEntry] {
        let canonical = directory.resolvingSymlinksInPath().standardizedFileURL
        guard contains(canonical, in: root.resolvingSymlinksInPath()) else {
            throw CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: directory.path])
        }
        let fm = FileManager.default
        // Do not turn a directory replaced by a link into a navigation route.
        let attributes = try fm.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: directory.path])
        }
        return try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).map { url in
            let values = try fm.attributesOfItem(atPath: url.path)
            let type = values[.type] as? FileAttributeType
            return LCFileEntry(url: url, isDirectory: type == .typeDirectory,
                isSymbolicLink: type == .typeSymbolicLink,
                size: (values[.size] as? NSNumber)?.int64Value ?? 0,
                fileNumber: (values[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0)
        }.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func deletionURL(for entry: LCFileEntry, root: URL) throws -> URL? {
        try validate(entry.url, in: root)
        let fm = FileManager.default
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fm.attributesOfItem(atPath: entry.url.path)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
        guard (attributes[.systemFileNumber] as? NSNumber)?.uint64Value == entry.fileNumber else {
            throw NSError(domain: "LCFileBrowser", code: 1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("lc.fileManager.itemChanged", comment: ""),
                NSFilePathErrorKey: entry.url.path
            ])
        }
        return entry.url
    }
}
