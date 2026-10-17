import Foundation

@main
struct LCFileBrowserTests {
    struct Failure: Error { let message: String }

    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try condition() == false { throw Failure(message: message) }
    }

    static func expectFailure(_ message: String, _ operation: () throws -> Void) throws {
        do { try operation() } catch { return }
        throw Failure(message: message)
    }

    static func main() throws {
        let fm = FileManager.default
        let fixture = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = fixture.appendingPathComponent("Documents")
        let outside = fixture.appendingPathComponent("Documents-old")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: fixture) }

        let directory = root.appendingPathComponent("Folder")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("file.txt")
        try Data("data".utf8).write(to: file)
        try Data("hidden".utf8).write(to: root.appendingPathComponent(".hidden"))
        let outsideFile = outside.appendingPathComponent("sentinel")
        try Data("sentinel".utf8).write(to: outsideFile)

        let link = root.appendingPathComponent("external-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: outside)
        let dangling = root.appendingPathComponent("dangling")
        try fm.createSymbolicLink(at: dangling, withDestinationURL: fixture.appendingPathComponent("missing"))

        let entries = try LCFileBrowser.load(directory: root, root: root)
        try check(entries.first?.name == "Folder", "directories are sorted first")
        try check(entries.contains { $0.name == ".hidden" }, "hidden files are visible")
        let linkEntry = try entries.first { $0.url == link }.unwrap("symlink listed")
        try check(linkEntry.isSymbolicLink && !linkEntry.isDirectory, "directory links are not navigation routes")
        try LCFileBrowser.validate(link, in: root)
        try check(try LCFileBrowser.deletionURL(for: linkEntry, root: root) == link, "the link itself can be deleted")
        try check(fm.fileExists(atPath: outsideFile.path), "validation preserves target")

        try expectFailure("a sibling prefix must not pass containment") {
            try LCFileBrowser.validate(outsideFile, in: root)
        }
        try expectFailure("a link in the parent path must not escape the root") {
            try LCFileBrowser.validate(link.appendingPathComponent("sentinel"), in: root)
        }
        try expectFailure("root cannot be deleted") {
            try LCFileBrowser.validate(root, in: root)
        }
        try expectFailure("directory URL trailing slash must not bypass root protection") {
            let directoryURL = URL(fileURLWithPath: root.path, isDirectory: true)
            try LCFileBrowser.validate(root, in: directoryURL)
        }
        try expectFailure("a directory replaced by a link cannot be browsed") {
            _ = try LCFileBrowser.load(directory: link, root: root)
        }
        try expectFailure("out-of-root directory cannot be browsed") {
            _ = try LCFileBrowser.load(directory: outside, root: root)
        }

        let original = try entries.first { $0.url == file }.unwrap("regular file listed")
        try check(try LCFileBrowser.deletionURL(for: original, root: root) == file, "unchanged item validates")
        try fm.moveItem(at: file, to: root.appendingPathComponent("old-file"))
        try Data("replacement".utf8).write(to: file)
        try expectFailure("replacement must not be deleted using stale confirmation") {
            _ = try LCFileBrowser.deletionURL(for: original, root: root)
        }
        try fm.removeItem(at: file)
        try check(try LCFileBrowser.deletionURL(for: original, root: root) == nil, "missing entry is already deleted")

        let danglingEntry = try entries.first { $0.url == dangling }.unwrap("dangling link listed")
        try check(try LCFileBrowser.deletionURL(for: danglingEntry, root: root) == dangling, "dangling link validates without following target")
        print("PASS: directory listing, links, hidden files, root/sibling/ancestor containment, replacement checks, missing entries")
    }
}

private extension Optional {
    func unwrap(_ message: String) throws -> Wrapped {
        guard let value = self else { throw LCFileBrowserTests.Failure(message: message) }
        return value
    }
}
