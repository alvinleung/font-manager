//
//  FontProvider.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-29.
//

import Foundation

// MARK: - API Response Root

struct GoogleFontsResponse: Codable {
    let kind: String
    let items: [GoogleFont]
}

// MARK: - Font Model

struct GoogleFont: Codable, FontFamilyPreviewInfo {
    let kind: String
    let family: String
    let category: FontCategory
    let variants: [FontVariant]
    let subsets: [String]
    let version: String
    let lastModified: String
    let files: [String: String]
    let axes: [FontAxis]?
    let fonts: [FontMetadata]?
}

// MARK: - Axis Model

struct FontAxis: Codable {
    let tag: String
    let min: Double
    let max: Double
    let step: Double
}

// MARK: - Font Metadata Model

struct FontMetadata: Codable {
    let weight: Int
    let style: FontStyle
}

// MARK: - Font Category Enum

enum FontCategory: String, Codable {
    case sansSerif = "sans-serif"
    case serif = "serif"
    case display = "display"
    case handwriting = "handwriting"
    case monospace = "monospace"
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = FontCategory(rawValue: rawValue) ?? .other
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: - Font Style Enum

enum FontStyle: String, Codable {
    case normal = "normal"
    case italic = "italic"
    case oblique = "oblique"
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = FontStyle(rawValue: rawValue) ?? .other
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: - Font Variant Enum

enum FontVariant: String, Codable {
    case regular
    case italic
    case weight100 = "100"
    case weight100Italic = "100italic"
    case weight200 = "200"
    case weight200Italic = "200italic"
    case weight300 = "300"
    case weight300Italic = "300italic"
    case weight400 = "400"
    case weight400Italic = "400italic"
    case weight500 = "500"
    case weight500Italic = "500italic"
    case weight600 = "600"
    case weight600Italic = "600italic"
    case weight700 = "700"
    case weight700Italic = "700italic"
    case weight800 = "800"
    case weight800Italic = "800italic"
    case weight900 = "900"
    case weight900Italic = "900italic"
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = FontVariant(rawValue: rawValue) ?? .other
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

class GoogleFontProvider: FontProviderProtocol {
    static let shared = GoogleFontProvider()
    private init() {}

    func fetchAvailable() async -> Result<[GoogleFont], Error> {
        let secret = GOOGLE_FONT_API_KEY
        guard let url = URL(string: "https://www.googleapis.com/webfonts/v1/webfonts?key=\(secret)")
        else {
            return .failure(
                NSError(
                    domain: "InvalidURL", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure(error)
        }

        let response: GoogleFontsResponse
        do {
            response = try JSONDecoder().decode(GoogleFontsResponse.self, from: data)
        } catch {
            return .failure(error)
        }

        return .success(response.items)
    }

    func install(font: GoogleFont) async {

    }

}
