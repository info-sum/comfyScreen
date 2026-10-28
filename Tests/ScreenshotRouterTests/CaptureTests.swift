//
//  CaptureTests.swift
//  ScreenshotRouterTests
//
//  설명: 캡처 파일 필터링, 스테이징, 저장 및 폴더 목록 즉시 추가 동작을 검증하는 단위 테스트입니다.
//

import Foundation
import Testing
@testable import ScreenshotRouter

struct CaptureTests {
    @Test func localizedNamesRejectUnrelatedAndPartialFiles() {
        let names = ["Screenshot 2026.png": true, "스크린샷 2026.jpg": true, "Screenshot 2026.JPEG": true,
                     ".Screenshot 2026.png": false, "photo.png": false, "Screenshot 2026.png.partial": false,
                     "Screenshotting.png": false]
        for (name, accepted) in names {
            #expect(CaptureFiles.matches(URL(fileURLWithPath: name)) == accepted)
        }
    }

    @Test func collisionSavePreservesExistingBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let date = Date(timeIntervalSince1970: 0)
        let firstSource = root.appendingPathComponent("Screenshot first.png")
        try Data("original".utf8).write(to: firstSource)
        let existing = try CaptureFiles.save(firstSource, to: target, date: date)
        let secondSource = root.appendingPathComponent("Screenshot second.png")
        try Data("new".utf8).write(to: secondSource)
        let saved = try CaptureFiles.save(secondSource, to: target, date: date)
        #expect(existing.lastPathComponent.hasPrefix("스크린샷_"))
        #expect(existing.pathExtension == "png")
        #expect(saved.lastPathComponent == existing.deletingPathExtension().lastPathComponent + " 2.png")
        #expect(try Data(contentsOf: existing) == Data("original".utf8))
        #expect(try Data(contentsOf: saved) == Data("new".utf8))
    }

    @Test func failedSaveRetainsSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Screenshot sample.png")
        try Data("retain".utf8).write(to: source)
        #expect(throws: (any Error).self) { try CaptureFiles.save(source, to: root.appendingPathComponent("missing")) }
        #expect(try Data(contentsOf: source) == Data("retain".utf8))
    }

    @Test func stageRecoversOriginalNameAndBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("스크린샷 original.png")
        try Data("capture".utf8).write(to: source)
        let pending = root.appendingPathComponent("pending")
        let staged = try CaptureFiles.stage(source, in: pending)
        let recovered = try CaptureFiles.recover(in: pending)
        #expect(recovered.map(\.url) == [staged])
        #expect(recovered.first?.filename == source.lastPathComponent)
        #expect(try Data(contentsOf: staged) == Data("capture".utf8))
    }

    @Test @MainActor func watcherIgnoresExistingAndStagesNewAfterStableProbe() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let watch = root.appendingPathComponent("watch")
        let pending = root.appendingPathComponent("pending")
        try FileManager.default.createDirectory(at: watch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let existing = watch.appendingPathComponent("Screenshot existing.png")
        try Data("old".utf8).write(to: existing)
        let watcher = CaptureWatcher(directory: watch, pending: pending)
        try watcher.start()
        defer { watcher.stop() }
        try Data("new".utf8).write(to: watch.appendingPathComponent("Screenshot new.png"))
        try Data("unrelated".utf8).write(to: watch.appendingPathComponent("photo.png"))
        let delivered: URL? = await withCheckedContinuation { continuation in
            watcher.onCapture = { url in
                guard watcher.onCapture != nil else { return }
                watcher.onCapture = nil
                continuation.resume(returning: url)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                guard watcher.onCapture != nil else { return }
                watcher.onCapture = nil
                continuation.resume(returning: nil)
            }
        }
        #expect(delivered?.lastPathComponent == "Screenshot new.png")
        #expect(try Data(contentsOf: existing) == Data("old".utf8))
        #expect(try CaptureFiles.recover(in: pending).count == 1)
    }

    @Test @MainActor func watcherDoesNotRestageSavedFileMarkedHandled() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let watch = root.appendingPathComponent("watch")
        let pending = root.appendingPathComponent("pending")
        try FileManager.default.createDirectory(at: watch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let watcher = CaptureWatcher(directory: watch, pending: pending)
        try watcher.start()
        defer { watcher.stop() }
        let source = root.appendingPathComponent("Screenshot saved.png")
        try Data("saved".utf8).write(to: source)
        let saved = try CaptureFiles.save(source, to: watch)

        watcher.ignore(saved)

        #expect(watcher.scan() == false)
        #expect(FileManager.default.fileExists(atPath: saved.path))
        #expect(try CaptureFiles.recover(in: pending).isEmpty)
    }

    @Test func canonicalDestinationsAndFileStability() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Screenshot stamp.png")
        try Data("first".utf8).write(to: source)
        let before = FileStamp(url: source)
        #expect(before == FileStamp(url: source))
        try Data("longer content".utf8).write(to: source)
        #expect(before != FileStamp(url: source))
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        #expect(Destination(url: alias).path == Destination(url: root).path)
    }

    @Test @MainActor func saveToChosenFolderCanAddDestinationWithoutDuplicates() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let watch = root.appendingPathComponent("watch", isDirectory: true)
        let pending = root.appendingPathComponent("pending", isDirectory: true)
        let oneOffFolder = root.appendingPathComponent("oneOff", isDirectory: true)
        let addedFolder = root.appendingPathComponent("added", isDirectory: true)
        try FileManager.default.createDirectory(at: watch, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oneOffFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: addedFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let model = RouterModel(watchDirectory: watch, pendingDirectory: pending, isolatedDestinations: [])

        // 1. addToDestinations: false(기본값)일 때는 파일만 저장하고 저장 폴더 목록은 비어 있어야 함
        let firstCapture = pending.appendingPathComponent("Screenshot first.png")
        try Data("first".utf8).write(to: firstCapture)
        model.pending = [PendingCapture(url: firstCapture, discovered: Date(timeIntervalSince1970: 10))]
        model.save(toFolder: oneOffFolder, addToDestinations: false)
        #expect(model.pending.isEmpty)
        #expect(model.destinations.isEmpty)

        // 2. addToDestinations: true일 때는 파일 저장과 동시에 해당 폴더가 저장 폴더 목록에 추가되고 선택되어야 함
        let secondCapture = pending.appendingPathComponent("Screenshot second.png")
        try Data("second".utf8).write(to: secondCapture)
        model.pending = [PendingCapture(url: secondCapture, discovered: Date(timeIntervalSince1970: 20))]
        model.save(toFolder: addedFolder, addToDestinations: true)
        #expect(model.pending.isEmpty)
        #expect(model.destinations.count == 1)
        #expect(model.destinations.first?.path == Destination(url: addedFolder).path)
        #expect(model.selection == model.destinations.first?.id)

        // 3. 이미 등록된 폴더(또는 심볼릭 링크)에 addToDestinations: true로 다시 저장해도 중복 등록되지 않아야 함
        let aliasFolder = root.appendingPathComponent("addedAlias")
        try FileManager.default.createSymbolicLink(at: aliasFolder, withDestinationURL: addedFolder)
        let thirdCapture = pending.appendingPathComponent("Screenshot third.png")
        try Data("third".utf8).write(to: thirdCapture)
        model.pending = [PendingCapture(url: thirdCapture, discovered: Date(timeIntervalSince1970: 30))]
        model.save(toFolder: aliasFolder, addToDestinations: true)
        #expect(model.pending.isEmpty)
        #expect(model.destinations.count == 1)
    }
}
