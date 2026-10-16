import Foundation
import Darwin

@MainActor
final class CaptureWatcher {
    let directory: URL
    let pending: URL
    var onCapture: ((URL) -> Void)?
    var onError: ((String) -> Void)?
    private var source: DispatchSourceFileSystemObject?
    private var probe: Task<Void, Never>?
    private var seen: Set<String> = []
    private var stamps: [URL: FileStamp] = [:]

    init(directory: URL, pending: URL) {
        self.directory = directory
        self.pending = pending
    }

    func start() throws {
        seen = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.scheduleProbe() }
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
        scheduleProbe()
    }

    func stop() {
        probe?.cancel()
        probe = nil
        source?.cancel()
        source = nil
    }

    func ignore(_ url: URL) {
        guard url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
            == directory.standardizedFileURL.resolvingSymlinksInPath() else { return }
        seen.insert(url.lastPathComponent)
        stamps.removeValue(forKey: url)
    }

    private func scheduleProbe() {
        guard probe == nil else { return }
        probe = Task { [weak self] in
            while let self, !Task.isCancelled {
                let needsProbe = self.scan()
                if !needsProbe { break }
                do { try await Task.sleep(for: .milliseconds(300)) }
                catch { break }
            }
            self?.probe = nil
        }
    }

    func scan() -> Bool {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { !seen.contains($0.lastPathComponent) && CaptureFiles.matches($0) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            var waiting = false
            for url in files {
                guard let stamp = FileStamp(url: url) else { continue }
                guard stamps[url] == stamp else {
                    stamps[url] = stamp
                    waiting = true
                    continue
                }
                do {
                    let staged = try CaptureFiles.stage(url, in: pending)
                    seen.insert(url.lastPathComponent)
                    stamps.removeValue(forKey: url)
                    onCapture?(staged)
                } catch {
                    seen.insert(url.lastPathComponent)
                    onError?("Could not stage \(url.lastPathComponent): \(error.localizedDescription). The original remains in the capture folder.")
                }
            }
            return waiting
        } catch {
            onError?("Cannot read the capture folder: \(error.localizedDescription)")
            return false
        }
    }
}
