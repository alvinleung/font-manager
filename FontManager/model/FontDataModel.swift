//
//  FontDataModel.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-24.
//


import Foundation
import SwiftData

enum FontSource: String {
    case system
    case googleFonts
}

@Model
class AppUserPreferences {
    // auto install from folder
    var watchedFolders: [URL] = []
    var demoText: String = "Typography" // default value
        
    init(watchedFolders: [URL] = [], demoText: String = "Typography") {
        self.watchedFolders = watchedFolders
        self.demoText = demoText
    }
}


@Model
class FontFamily {
    @Attribute(.unique) var id: UUID
    var name: String
    var designer: String?
    var category: String?
    var addedAt: Date
    
    @Relationship(deleteRule: .cascade) var files: [FontFile]

    init(name: String, designer: String? = nil, category: String,  source: String = "local", addedAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.designer = designer
        self.addedAt = addedAt
        self.category = category
        self.files = []
    }
}

@Model
class FontFile {
    @Attribute(.unique) var id: UUID
    var style: String // e.g., "Regular", "Bold", "Italic"
    var weight: Int // numeric weight (e.g., 400, 700)
    var italic: Bool
    var source: String // system or googleFont
    var path: URL? // optional if stored locally
    var originPath: URL? // optional if synced or downloadable
    var format: String // e.g., "ttf", "otf", "woff2"
    var addedAt: Date

    @Relationship(inverse: \FontFamily.files) var family: FontFamily?

    init(style: String, weight: Int = 400, italic: Bool = false, source: String,
         path: URL? = nil, originPath: URL? = nil, format: String = "ttf", addedAt: Date = .now) {
        self.id = UUID()
        self.style = style
        self.weight = weight
        self.italic = italic
        self.source = source
        self.path = path
        self.originPath = originPath
        self.format = format
        self.addedAt = addedAt
    }
}
