//
//  CompareFiles.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-26.
//


import Foundation
import CryptoKit

/// Returns the SHA256 hash of a file as a hex string
fileprivate func sha256Hash(of url: URL) -> String? {
    guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
        return nil
    }
    
    defer { try? fileHandle.close() }

    var hasher = SHA256()
    
    while autoreleasepool(invoking: {
        let data = fileHandle.readData(ofLength: 1024 * 1024) // Read 1MB chunks
        if data.isEmpty { return false }
        hasher.update(data: data)
        return true
    }) {}

    let digest = hasher.finalize()
    return digest.map { String(format: "%02x", $0) }.joined()
}

/// Efficiently checks if two files are duplicates by comparing size and SHA256 hash
func checkAreFilesEqualContent(_ url1: URL, _ url2: URL) -> Bool {
    let fileManager = FileManager.default

    do {
        let attr1 = try fileManager.attributesOfItem(atPath: url1.path)
        let attr2 = try fileManager.attributesOfItem(atPath: url2.path)

        guard let size1 = attr1[.size] as? UInt64,
              let size2 = attr2[.size] as? UInt64,
              size1 == size2 else {
            return false // Different size → definitely not a match
        }

        // Same size → compare hashes
        guard let hash1 = sha256Hash(of: url1),
              let hash2 = sha256Hash(of: url2) else {
            return false
        }

        return hash1 == hash2

    } catch {
        print("Error comparing files: \(error)")
        return false
    }
}
