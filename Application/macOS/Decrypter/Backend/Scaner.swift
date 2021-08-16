//
//  main.swift
//  AppAnalysis
//
//  Created by Lakr Aream on 2021/8/16.
//

import Foundation
import Dog

public enum BinaryItem {
    case app(url: URL)
    case framework(url: URL)
    case appex(url: URL)
    case unknown(url: URL)
}

public class AppAnalyzer {
    public static let shared = AppAnalyzer()
    private init() { }
    
    func obtainBinaryLocations(with searchPath: URL) -> [BinaryItem] {
        FileManager
            .default
            .enumerator(atPath: searchPath.path)?
            .allObjects
            .map { $0 as? String }
            .compactMap { $0 }
            .map { searchPath.appendingPathComponent($0) }
            .map { convertToBinaryItem(with: $0) }
            .compactMap { $0 }
            ?? []
    }

    private func convertToBinaryItem(with url: URL) -> BinaryItem? {
        if url.lastPathComponent == "Info.plist" {
            do {
                let data = try Data(contentsOf: url)
                let result = try PropertyListSerialization
                    .propertyList(from: data,
                                  options: .mutableContainersAndLeaves,
                                  format: .none)
                guard let decode = result as? [String: Any] else {
                    Dog.shared.join(self, "[E] decode failed on metadata \(url.path)")
                    return nil
                }
                guard let executableName = decode["CFBundleExecutable"] as? String else {
                    Dog.shared.join(self, "[-] executable not found in metadata \(url.path)")
                    return nil
                }
                let upLevel = url.deletingLastPathComponent()
                let baseName = upLevel.lastPathComponent
                let finder = upLevel.appendingPathComponent(executableName)

                var isDir = ObjCBool(false)
                let check = FileManager
                    .default
                    .fileExists(atPath: finder.path, isDirectory: &isDir)
                if isDir.boolValue || !check {
                    Dog.shared.join(self, "[E] target executable is not a regular file")
                    Dog.shared.join(self, "    isDir? \(isDir.boolValue) fileExists? \(check)")
                    Dog.shared.join(self, "    \(finder.path)")
                    return nil
                }

                if baseName.hasSuffix(".appex") {
                    Dog.shared.join(self, "[AppEx] \(finder.path)")
                    return .appex(url: finder)
                }
                if baseName.hasSuffix(".framework") {
                    Dog.shared.join(self, "[Framework] \(finder.path)")
                    return .framework(url: finder)
                }
                if baseName.hasSuffix(".app") {
                    Dog.shared.join(self, "[App] \(finder.path)")
                    return .app(url: finder)
                }
                return nil
            } catch {
                Dog.shared.join(self, error.localizedDescription)
                return nil
            }
        }

        return nil
    }
}
