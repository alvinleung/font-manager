//
//  SyncFontFolder.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-25.
//

import AppKit
import Foundation

struct FontSync {

    static func syncWithPermission() async {

        let fileManager = FileManager.default

        let fontDirURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Fonts", isDirectory: true)
        let copyDirURL = fileManager.homeDirectoryForCurrentUser

        let fontDirResult = await SecuredScopeAccess.request(suggested: fontDirURL)
        let formDirResult = await SecuredScopeAccess.request(suggested: copyDirURL, mustAsk: true)

        // Unwrap sync folder result
        guard case let .success(copyFromDir) = formDirResult,
            case let .success(fontRootDir) = fontDirResult
        else {
            switch formDirResult {
            case .failure(.noSelection):
                print("Sync folder not selected")
            case .failure(.unableToBookmark):
                print("Cannot bookmark sync folder")
            default:
                print("Unknown error")
            }

            switch fontDirResult {
            case .failure(.noSelection):
                print("to dir folder was not selected")
            case .failure(.unableToBookmark):
                print("unable to bookmark user font folder")
            default:
                print("Unknown error")
            }
            return
        }

        // toggling access state
        copyFromDir.beginAccess()
        fontRootDir.beginAccess()

        guard let syncSubDir = ensureDirExists(at: fontRootDir.url.appendingPathComponent("Sync"))
        else {
            fontRootDir.endAccess()
            fontRootDir.endAccess()
            print("Cannot access sync directory")
            return
        }

        guard
            let syncTargetDir = ensureDirExists(
                at: syncSubDir.appendingPathComponent(copyFromDir.url.lastPathComponent))
        else {
            fontRootDir.endAccess()
            fontRootDir.endAccess()
            print("Cannot access sync sub - directory")
            return
        }

        await syncDir(fromDir: copyFromDir.url, toDir: syncTargetDir)

        fontRootDir.endAccess()
        copyFromDir.endAccess()
    }

    private static func ensureDirExists(at url: URL) -> URL? {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue ? url : nil
        }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch {
            print("Failed to create directory at \(url.path): \(error)")
            return nil
        }
    }

    private static func syncDir(fromDir: URL, toDir: URL) async {
        let fileManager = FileManager.default

        let toDirFontFiles = listFontFiles(dir: toDir)
        let fromDirFontFiles = listFontFiles(dir: fromDir)

        // sync file into source
        enum SyncOperation {
            case copyFromSource
            case removeFromSystem
        }

        var operations = [(URL, SyncOperation)]()

        // the add and update sync operations
        for from in fromDirFontFiles {

            let fileWithEqualName = toDirFontFiles.first(where: {
                $0.lastPathComponent == from.lastPathComponent
            })

            // when path doesn't exist in to folder, add the new file to folder
            guard let matchedFile = fileWithEqualName else {
                operations.append((from, .copyFromSource))
                continue
            }

            // deep compare the two, not not same, then ovewrite
            if !checkAreFilesEqualContent(from, matchedFile) {
                operations.append((fileWithEqualName!, .copyFromSource))
            }
        }

        // the remove operations
        for to in toDirFontFiles {
            let fileWithEqualName = fromDirFontFiles.first(where: {
                $0.lastPathComponent == to.lastPathComponent
            })

            // file doesn't exist in the new dir state,
            // remove the file
            if fileWithEqualName == nil {
                operations.append((to, .removeFromSystem))
            }
        }

        // execute the file operations
        for (fileURL, operation) in operations {
            switch operation {
            case .copyFromSource:
                let fromURL = fileURL
                let toURL = toDir.appendingPathComponent(fileURL.lastPathComponent)

                if (try? fileManager.copyItem(at: fromURL, to: toURL)) == nil {
                    print("unable to copy file")
                }
            case .removeFromSystem:
                if (try? fileManager.removeItem(at: fileURL)) == nil {
                    print("unable to copy file")
                }
            }
        }

        // do this recursively if there is sub-directory
        let subDirectories = listSubDirectory(dir: fromDir)
        print(subDirectories)

        for nextFromPath in subDirectories {
            let nextToPath = toDir.appendingPathComponent(nextFromPath.lastPathComponent)
            let appendResult = ensureDirExists(at: nextToPath)

            guard let nextToDir = appendResult else {
                print("Unable to access sub-directory: \(nextToPath)")
                continue
            }

            print("Next from path: \(nextFromPath)")
            print("Next to path: \(nextToPath)")

            Task {
                await syncDir(fromDir: nextFromPath, toDir: nextToDir)
            }
        }

        print("Completed Sync")

    }

    private static func listSubDirectory(dir: URL) -> [URL] {
        let fileManager = FileManager.default
        var result: [URL] = []

        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            )
        else {
            print("Unable to list contents of \(dir.path)")
            return result
        }

        for url in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                result.append(url)
            }
        }

        return result
    }

    private static func listFontFiles(dir: URL) -> [URL] {
        var result = [URL]()

        // continue operation with access
        let fileManager = FileManager.default
        let files = try? fileManager.contentsOfDirectory(atPath: dir.path)

        guard files != nil else {
            print("Unable to read directory: \(dir.path)")
            return result
        }

        let fontFiles = files?.filter { fileName in
            let fullPath = dir.appendingPathComponent(fileName)
            return FontSync.isFontFile(url: fullPath)
        }

        for fileName in fontFiles ?? [] {
            let fullPath = dir.appendingPathComponent(fileName)
            result.append(fullPath)
        }

        return result
    }

    /*
    
     Check file magic numbers (data signatures)
     Font files start with specific bytes (called magic numbers) that identify their type:
    
     Format    Magic Number (Hex)
     ------    -------------------------------
     TTF       00 01 00 00 or 'true' or 'typ1'
     OTF       'OTTO' (4F 54 54 4F)
     WOFF      'wOFF' (77 4F 46 46)
     WOFF2     'wOF2' (77 4F 46 32)
    
     */
    private static func isFontFile(url: URL) -> Bool {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? fileHandle.close() }

        let magicLength = 4
        let data = fileHandle.readData(ofLength: magicLength)
        guard data.count == magicLength else { return false }

        let magic = [UInt8](data)

        // Check for 'OTTO' (OTF)
        if magic == [0x4F, 0x54, 0x54, 0x4F] { return true }

        // Check for TTF magic numbers (00 01 00 00 or 'true' or 'typ1')
        if magic == [0x00, 0x01, 0x00, 0x00] { return true }
        // You can add more checks here for other valid headers

        return false
    }

    // this is just a namesapce
    private init() {}
}
