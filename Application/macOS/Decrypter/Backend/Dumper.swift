//
//  Agent.swift
//  Decrypter
//
//  Created by Lakr Aream on 2021/8/16.
//

import Foundation
import MachO
import Dog

@_silgen_name("mremap_encrypted")
func mremap_encrypted(_: UnsafeMutableRawPointer, _: Int, _: UInt32, _: UInt32, _: UInt32) -> Int32

class Dumper {
    static func dump(at location: URL) -> URL? {
        // file locations
        let targetName = UUID().uuidString
        let targetDir = NSTemporaryDirectory()
            .appending("wiki.qaq.dumper")
            .appending("/")
        let targetLocation = targetDir
            .appending(targetName)
        Dog.shared.join(self, "[i] preparing decrypt to \(targetLocation)")
        // copy file
        do {
            try FileManager
                .default
                .createDirectory(atPath: targetDir,
                                 withIntermediateDirectories: true,
                                 attributes: nil)
            try FileManager
                .default
                .copyItem(atPath: location.path,
                          toPath: targetLocation)

        } catch {
            Dog.shared.join(self, "[E] failed to copy resouces")
            return nil
        }
        var success: Bool = false

        // map file with mmap
        Dumper.mapFile(path: location.path,
                       mutable: false) { baseSize, baseDescriptor, baseRaw in
            defer {
                if baseDescriptor > 0 {
                    munmap(baseRaw, baseSize)
                }
            }
            guard baseRaw != nil else {
                Dog.shared.join(self, "[E] failed to read from file \(location.path)")
                return
            }
            Dumper.mapFile(path: targetLocation,
                           mutable: true) { dumperSize, dumperDescriptor, dumperRaw in
                defer {
                    if dumperDescriptor > 0 {
                        munmap(dumperRaw, dumperSize)
                    }
                }
                guard let dumperRaw = dumperRaw else {
                    Dog.shared.join(self, "[E] failed to open mmap for saving")
                    return
                }
                guard baseSize == dumperSize else {
                    Dog.shared.join(self, "[E] failed to check memory")
                    return
                }
                let header = UnsafeMutableRawPointer(mutating: dumperRaw)
                    .assumingMemoryBound(to: mach_header_64.self)
                if header.pointee.magic == MH_MAGIC_64,
                   header.pointee.cputype == CPU_TYPE_ARM64,
                   header.pointee.cpusubtype == CPU_SUBTYPE_ARM64_ALL { }
                else {
                    Dog.shared.join(self, "[-] malformed binary header, continue anyway...")
                }

                guard var curcmd = UnsafeMutablePointer<load_command>(bitPattern: UInt(bitPattern: header) + UInt(MemoryLayout<mach_header_64>.size))
                else {
                    Dog.shared.join(self, "[E] malformed curcmd")
                    return
                }

                var segcmd: UnsafeMutablePointer<load_command>!
                for _: UInt32 in 0 ..< header.pointee.ncmds {
                    segcmd = curcmd
                    if segcmd.pointee.cmd == LC_ENCRYPTION_INFO_64 {
                        let command = UnsafeMutableRawPointer(mutating: segcmd)
                            .assumingMemoryBound(to: encryption_info_command_64.self)
                        let result = Dumper.dump(descriptor: baseDescriptor,
                                                 dupe: dumperRaw,
                                                 info: command.pointee)
                        if result { command.pointee.cryptid = 0 }
                        break
                    }
                    curcmd = UnsafeMutableRawPointer(curcmd)
                        .advanced(by: Int(curcmd.pointee.cmdsize))
                        .assumingMemoryBound(to: load_command.self)
                }

                Dog.shared.join(self, "[i] done this binary")
                success = true
            }
        }
        if success {
            return URL(fileURLWithPath: targetLocation)
        }
        return nil
    }

    fileprivate static func dump(descriptor: Int32, dupe: UnsafeMutableRawPointer, info: encryption_info_command_64) -> Bool {
        let base = mmap(nil, Int(info.cryptsize), PROT_READ | PROT_EXEC, MAP_PRIVATE, descriptor, off_t(info.cryptoff))
        if base == MAP_FAILED {
            return false
        }
        let error = mremap_encrypted(base!, Int(info.cryptsize), info.cryptid, UInt32(CPU_TYPE_ARM64), UInt32(CPU_SUBTYPE_ARM64_ALL))
        if error != 0 {
            munmap(base, Int(info.cryptsize))
            return false
        }
        memcpy(dupe + UnsafeMutableRawPointer.Stride(info.cryptoff), base, Int(info.cryptsize))
        munmap(base, Int(info.cryptsize))

        return true
    }

    fileprivate static func mapFile(path: UnsafePointer<CChar>, mutable: Bool, handle: (Int, Int32, UnsafeMutableRawPointer?) -> Void) {
        let f = open(path, mutable ? O_RDWR : O_RDONLY)
        if f < 0 {
            handle(0, 0, nil)
            return
        }

        var s = stat()
        if fstat(f, &s) < 0 {
            close(f)
            handle(0, 0, nil)
            return
        }

        let base = mmap(nil, Int(s.st_size), mutable ? PROT_READ | PROT_WRITE : PROT_READ, mutable ? MAP_SHARED : MAP_PRIVATE, f, 0)
        if base == MAP_FAILED {
            close(f)
            handle(0, 0, nil)
            return
        }

        handle(Int(s.st_size), f, base)
    }
}
