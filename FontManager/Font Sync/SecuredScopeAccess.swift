//
//  DirectoryAccess.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-26.
//

import Foundation
import AppKit

struct SecuredScopeAccess {
    let url:URL
    
    func beginAccess() {
        // Access folder in sandbox
        guard self.url.startAccessingSecurityScopedResource() else {
            print("Failed to start accessing security-scoped resource.")
            return
        }
    }
    
    func endAccess() {
        self.url.stopAccessingSecurityScopedResource()
    }
    
    
    @MainActor
    static private func openFolderDialogAsync(title: String, defaultDirectory: URL?) async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.title = "Select your Fonts Folder in System (usually ~/Library/Fonts)"
            panel.directoryURL = defaultDirectory
            
            panel.begin { response in
                if response == .OK {
                    continuation.resume(returning: panel.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    enum DirAccessRequestError: Error {
        case noSelection
        case unableToBookmark
    }
    
    static func request(suggested: URL, mustAsk: Bool = false) async -> Result<SecuredScopeAccess, DirAccessRequestError> {
        if mustAsk {
            try! DirectoryAccessBookmark.clear(key: suggested.path)
        }
        
        // check if there is permission bookmark on font folder
        // the path is used a Security bookmark key
        let attempt = DirectoryAccessBookmark.retrieve(key: suggested.path)
        
        if case let .success(scopeUrl) = attempt {
            return .success(SecuredScopeAccess(url: scopeUrl))
        }

        
        let selectedURL = await openFolderDialogAsync(
            title: "Select System Fonts Folder",
            defaultDirectory: suggested
        )
        
        guard let folderURL = selectedURL else {
            return .failure(.noSelection)
        }
        
        let saveBookmarkResult = Result { try DirectoryAccessBookmark.save(key: suggested.path, url: folderURL) }
        if case .failure = saveBookmarkResult {
            return .failure(.unableToBookmark)
        }
        
        return .success(SecuredScopeAccess(url: folderURL))
    }
}

struct DirectoryAccessBookmark {
    enum BookmarkRetrievalError: Error {
        case notFound
        case stale
        case invalidBookmarkData(Error)
    }
    
    static func retrieve(key: String) -> Result<URL, Error> {
        guard let bookmarkData = UserDefaults.standard.data(forKey: key) else {
            return .failure(BookmarkRetrievalError.notFound)
        }
        
        var isStale = false
        
        let result = Result {
            try URL(resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale)
        }
        
        switch result {
        case .success(let url):
            if isStale {
                return .failure(BookmarkRetrievalError.stale)
            } else {
                return .success(url)
            }
            
        case .failure(let error):
            return .failure(BookmarkRetrievalError.invalidBookmarkData(error))
        }
    }
    
    static func save(key: String, url: URL) throws {
        let bookmarkData = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmarkData, forKey: key)
    }
    
    static func clear(key: String) throws {
        UserDefaults.standard.set(nil, forKey: key)
    }
}
