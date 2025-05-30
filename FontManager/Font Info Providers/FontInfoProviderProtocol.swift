//
//  FontProvider.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-29.
//

protocol FontFamilyPreviewInfo {
    var family: String { get }
    var files: [String:String] { get }
}

protocol FontProviderProtocol {
    associatedtype FontInfo: FontFamilyPreviewInfo

    // fetch all the metadata related the font
    func fetchAvailable() async -> Result<[FontInfo], Error>

    // install the font from the source, meaning,
    // copying it from the source to the user's
    // font folder ~/Library/font
    func install(font: FontInfo) async
}
