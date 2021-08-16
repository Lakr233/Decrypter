//
//  Agent.swift
//  Decrypter
//
//  Created by Lakr Aream on 2021/8/16.
//

import Foundation
import ZipArchive
import Dog

func dumpApplicationAt(location orig: URL,
                       saveTo target: URL,
                       updateProgress: @escaping (Int) -> Void)
    -> URL
{
    let realTarget = target.appendingPathComponent(orig.lastPathComponent)
    if FileManager.default.fileExists(atPath: realTarget.path) {
        try? FileManager.default.removeItem(at: realTarget)
    }
    try! FileManager.default.copyItem(at: orig, to: realTarget)
    let binarys = AppAnalyzer.shared.obtainBinaryLocations(with: orig)

    updateProgress(10)

    var i = 0
    for item in binarys {
        func beginDump(url: URL) {
            Dog.shared.join("Dumper", "[i] requesting binary at \(url.path) to decrypt")
            guard let result = Dumper.dump(at: url) else {
                return
            }
            let origAppLocation = orig.path
            let targetAppLocation = realTarget
            let scannedLocation = url.path
            var trailing = scannedLocation.dropFirst(origAppLocation.count)
            if trailing.hasPrefix("/") {
                trailing.removeFirst()
            }
            let target = targetAppLocation.appendingPathComponent(String(trailing))
            do {
                try? FileManager.default.removeItem(atPath: target.path)
                try FileManager.default.copyItem(atPath: result.path, toPath: target.path)
            } catch {
                Dog.shared.join("Dumper", "[E] failed to overwrite target binary \(target.path) \(error.localizedDescription)")
            }
            Dog.shared.join("Dumper", "[i] Decrypted binary to \(target.path)")
        }
        switch item {
        case let .app(url): beginDump(url: url)
        case let .appex(url): beginDump(url: url)
        case let .framework(url): beginDump(url: url)
        case let .unknown(url): beginDump(url: url)
        }

        i += 1
        updateProgress(i * 80 / binarys.count)
    }

    // create ipa
    let container = target.appendingPathComponent("container")
    let payload = container.appendingPathComponent("Payload")
    try? FileManager.default.removeItem(atPath: payload.path)
    try? FileManager.default.createDirectory(at: payload,
                                             withIntermediateDirectories: true,
                                             attributes: nil)
    try? FileManager.default.copyItem(atPath: realTarget.path,
                                      toPath: payload.appendingPathComponent(orig.lastPathComponent).path)
    let ipa = target
        .appendingPathComponent(orig.lastPathComponent)
        .deletingPathExtension()
        .appendingPathExtension("ipa")
    SSZipArchive.createZipFile(atPath: ipa.path,
                               withContentsOfDirectory: container.path,
                               keepParentDirectory: false,
                               withPassword: nil) { curr, sum in
        let progress = Progress(totalUnitCount: Int64(sum))
        progress.completedUnitCount = Int64(curr)
        updateProgress(Int(progress.fractionCompleted * 20) + 80)
    }
    try? FileManager.default.removeItem(atPath: container.path)

    updateProgress(100)
    return realTarget
}
