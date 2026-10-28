import Foundation
import Darwin

struct Destination: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let path: String

    init(url: URL) {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        name = canonical.lastPathComponent
        path = canonical.path
    }

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
    var writable: Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &directory)
            && directory.boolValue && FileManager.default.isWritableFile(atPath: path)
    }
}

struct PendingCapture: Identifiable {
    let url: URL
    let discovered: Date
    var id: URL { url }
    var filename: String { url.lastPathComponent }
}

struct FileStamp: Equatable {
    let size: Int
    let modified: Date

    init?(url: URL) {
        var freshURL = url
        freshURL.removeAllCachedResourceValues()
        guard let values = try? freshURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, let date = values.contentModificationDate else { return nil }
        self.size = size
        modified = date
    }
}

enum CaptureFiles {
    static func matches(_ url: URL) -> Bool {
        let name = url.deletingPathExtension().lastPathComponent
        return ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased())
            && ["Screenshot ", "스크린샷 "].contains(where: name.hasPrefix)
    }

    static func stage(_ source: URL, in pending: URL) throws -> URL {
        let folder = pending.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(source.lastPathComponent)
        guard renamex_np(source.path, target.path, UInt32(RENAME_EXCL)) == 0 else {
            let failure = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            try? FileManager.default.removeItem(at: folder)
            throw failure
        }
        return target.resolvingSymlinksInPath()
    }

    static func defaultName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "스크린샷_\(formatter.string(from: date))"
    }

    /// Turns a name typed by the user into a file name without extension, or nil when nothing usable is left.
    /// Path separators become hyphens, a typed extension matching `ext` is dropped,
    /// and leading dots are removed so the saved file is never hidden.
    static func cleanName(_ typed: String, extension ext: String) -> String? {
        var name = ""
        for scalar in typed.unicodeScalars {
            name.unicodeScalars.append(scalar.properties.generalCategory == .control ? " " : scalar)
        }
        name = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let typedExtension = name.range(of: "." + ext, options: [.caseInsensitive, .anchored, .backwards]) {
            name.removeSubrange(typedExtension)
        }
        name = String(name.drop { $0 == "." }).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// Copies `source` into `directory` as `name`, or as the default name for `date` when `name` has nothing usable.
    /// Never overwrites: a clash appends " 2", " 3", and so on.
    static func save(_ source: URL, to directory: URL, name: String = "", date: Date = .now) throws -> URL {
        let ext = source.pathExtension.lowercased()
        let baseName = cleanName(name, extension: ext) ?? defaultName(for: date)
        var number = 1
        while true {
            let suffix = number == 1 ? "" : " \(number)"
            let target = directory.appendingPathComponent(fitted(baseName, suffix: suffix, extension: ext))
            do {
                try FileManager.default.copyItem(at: source, to: target)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                number += 1
                continue
            }
            try FileManager.default.removeItem(at: source)
            return target
        }
    }

    /// macOS allows 255 UTF-16 units per decomposed file name (a Hangul syllable takes 2–3),
    /// so a very long name loses its end instead of failing the save.
    private static func fitted(_ baseName: String, suffix: String, extension ext: String) -> String {
        var base = baseName
        while base.count > 1, (base + suffix + "." + ext).decomposedStringWithCanonicalMapping.utf16.count > 255 {
            base.removeLast()
        }
        return base + suffix + "." + ext
    }

    static func recover(in directory: URL) throws -> [PendingCapture] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.creationDateKey, .isRegularFileKey]) else { return [] }
        var result: [PendingCapture] = []
        for case let url as URL in enumerator where matches(url) {
            guard FileStamp(url: url) != nil else { continue }
            let values = try url.resourceValues(forKeys: [.creationDateKey])
            result.append(PendingCapture(url: url.resolvingSymlinksInPath(), discovered: values.creationDate ?? .distantPast))
        }
        return result.sorted { $0.discovered < $1.discovered }
    }
}
