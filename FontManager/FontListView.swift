//
//  FontListView.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-22.
//

import Combine
import CoreText
import Foundation
import SwiftData
import SwiftUI

struct ColorMode {
    let name: String
    let foreground: Color
    let background: Color
}

let modeDark = ColorMode(name: "dark", foreground: .white, background: .black)
let modeLight = ColorMode(name: "light", foreground: .black, background: .white)

struct FontView: View {
    public let allFonts: [FontFamily]
    public let loadingProgress: Double
    public let onRefreshDB: () -> Void

    public let preferences: AppUserPreferences
    public let context: ModelContext

    @State private var searchText = ""
    @State var demoText: String

    var filteredFonts: [FontFamily] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Regex to match quoted substrings OR sequences of non-space, non-+ chars
        let pattern = "\"[^\"]+\"|[^\\s+]+"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return allFonts
        }

        let nsrange = NSRange(query.startIndex..<query.endIndex, in: query)
        let matches = regex.matches(in: query, options: [], range: nsrange)

        let parts = matches.compactMap { match -> String? in
            if let range = Range(match.range, in: query) {
                return String(query[range])
            }
            return nil
        }

        let matchers: [(FontFamily) -> Bool] = parts.compactMap { part in
            if part.hasPrefix("\"") && part.hasSuffix("\"") && part.count > 1 {
                // Exact match inside quotes
                let exact = part.dropFirst().dropLast().lowercased()
                return { $0.name.lowercased() == exact }
            } else if part.hasPrefix("\"") {
                // Partial match fallback if only leading quote
                let partial = part.dropFirst().lowercased()
                return { $0.name.lowercased().contains(partial) }
            } else if !part.isEmpty {
                let target = part.lowercased()
                return { $0.name.lowercased().contains(target) }
            } else {
                return nil
            }
        }

        guard !matchers.isEmpty else {
            return allFonts
        }

        return allFonts.filter { font in
            matchers.contains { $0(font) }
        }
    }

    @State private var hoveredFont: String?
    @State private var focusedFont: String?

    @EnvironmentObject var fontPreviewState: FontPreviewState
    @State private var colorMode: ColorMode = modeDark

    var body: some View {
        let previewFontSize = fontPreviewState.size

        VStack {
            HStack {
                Spacer()
                if loadingProgress != 1.0 {
                    if loadingProgress == 0 {
                        Text("Loading...").font(.caption)
                    } else {
                        ProgressView(value: loadingProgress)
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.25)
                    }
                } else {
                    Text("Refresh").font(.caption).onTapGesture {
                        onRefreshDB()
                    }
                }

                if colorMode.name == "dark" {
                    Image(systemName: "moon")
                        .onTapGesture { colorMode = modeLight }
                        .padding(4)
                }

                if colorMode.name == "light" {
                    Image(systemName: "sun.min")
                        .onTapGesture { colorMode = modeDark }
                        .colorInvert()
                        .padding(4)
                }
            }
            .frame(height: 24)
            .padding(.top, 2)
            .padding(.trailing, 2)

            TextField("Find fonts...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 24, weight: .light))
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .foregroundColor(colorMode.foreground)
                .task(id: demoText) {
                    // debouce save demo text
                    try? await Task.sleep(for: .milliseconds(800))
                    guard !Task.isCancelled else { return }

                    print("saving context")
                    preferences.demoText = demoText
                    try! context.save()
                }.onDisappear {
                    preferences.demoText = demoText
                    try! context.save()
                }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredFonts, id: \.self) { family in
                        FontRow(
                            family: family,
                            demoText: $demoText,
                            isHovered: hoveredFont == family.name,
                            isFocused: focusedFont == family.name,
                            onTapTitle: {
                                // Regex to extract all quoted font names
                                let pattern = "\"[^\"]+\""

                                // Extract all quoted substrings from current searchText
                                let regex = try? NSRegularExpression(pattern: pattern)
                                let nsrange = NSRange(
                                    searchText.startIndex..<searchText.endIndex, in: searchText)
                                let matches =
                                    regex?.matches(in: searchText, options: [], range: nsrange)
                                    ?? []

                                // Map matches to string array
                                var fonts = matches.compactMap { match -> String? in
                                    if let range = Range(match.range, in: searchText) {
                                        return String(searchText[range])
                                    }
                                    return nil
                                }

                                // Append the new font wrapped in quotes
                                let newFont = "\"\(family.name)\""

                                // Avoid duplicates
                                if !fonts.contains(newFont) {
                                    fonts.append(newFont)
                                }

                                // Rebuild searchText with ' + ' separator
                                searchText = fonts.joined(separator: " + ")
                            },
                            onHoverChanged: { hovering in
                                hoveredFont = hovering ? family.name : nil
                            },
                            onFocusedChanged: {
                                focusedFont = family.name
                            },
                            previewFontSize: previewFontSize,
                            colorMode: colorMode
                        )
                    }
                }
            }
            .background(colorMode.background)
        }
        .background(colorMode.background)
    }

}

struct FontRow: View {
    let family: FontFamily
    @Binding var demoText: String
    let isHovered: Bool
    let isFocused: Bool
    let onTapTitle: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onFocusedChanged: () -> Void
    let previewFontSize: CGFloat
    let colorMode: ColorMode

    var body: some View {
        let name = family.name

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text(name)
                    .font(.caption)
                    .opacity(0.6)
                    .onTapGesture {
                        onTapTitle()
                    }
                Spacer()

                HStack(spacing: 4) {
                    //                    Text(family.category ?? "No category").font(.caption)
                    //                        .opacity(0.6)
                    //                    Text(family.files[0].source ?? "Unkown source").font(.caption)
                    //                        .opacity(0.6)

                    Button(action: {
                        print(family.files.map { $0.path })
                        print(family.files.count)
                        let fontURLs = findFontFileURLs(familyName: name)
                        if fontURLs.isEmpty {
                            print("No font files found for family: \(name)")
                        } else {
                            copyFontsToClipboard(urls: fontURLs)
                        }
                    }) {
                        Text("Copy \(family.files.count) file\(family.files.count > 1 ? "s" : "")")
                            .font(.caption)
                    }
                    .buttonStyle(AuxButtonStyle())

                    Button(action: {
                        let pathsToOpen = family.files.reduce(into: [URL]()) { result, file in
                            print(file.path ?? "")
                            guard let p = file.path else { return }  // Assuming file.path is of type URL?
                            result.append(p)
                        }
                        print(pathsToOpen)
                        revealFontsInFinder(urls: pathsToOpen)
                        //                                                let fontURLs = findFontFileURLs(familyName: name)
                        //                        if fontURLs.isEmpty {
                        //                            print("No font files found for family: \(name)")
                        //                        } else {
                        //                            print(fontURLs)
                        //                            revealFontsInFinder(urls: fontURLs)
                        //                        }
                    }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(AuxButtonStyle())
                }
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            }

            MultilineTextEditor(
                text: $demoText,
                placeholder: family.name,
                font: Font.custom(name, size: previewFontSize),
                foregroundColor: colorMode.foreground,
                backgroundColor: colorMode.background,
                minHeight: previewFontSize,
                isFocused: isFocused
            )
        }
        .padding(.bottom, 8)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            onFocusedChanged()
        }
        .background(colorMode.background)
        .foregroundColor(colorMode.foreground)
        .onHover { hovering in
            onHoverChanged(hovering)
        }
    }
}

struct MultilineTextEditor: View {
    @Binding var text: String
    var placeholder: String = "Enter text..."
    var font: Font = .body
    var foregroundColor: Color = .primary
    var backgroundColor: Color = .clear
    var minHeight: CGFloat = 32
    var isFocused: Bool = false

    @FocusState var shouldFocusTextEditor: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundColor(foregroundColor.opacity(0.7))
                    .padding(0)
                    .padding(.leading, -1)
                    .padding(.vertical, 4)
            }
            TextEditor(text: $text)
                .font(font)
                .padding(0)
                .padding(.leading, 0)
                .padding(.vertical, 4)
                .offset(x: -4)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(foregroundColor)
                .scrollIndicators(.never)
                .cornerRadius(0)
                .focused($shouldFocusTextEditor)
                .onChange(of: isFocused) { oldValue, newValue in
                    shouldFocusTextEditor = newValue
                }
        }
        .padding(0)
        .frame(minHeight: minHeight)
        .background(backgroundColor)

    }
}

struct AuxButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

func findFontFileURLs(familyName: String) -> [URL] {
    guard let members = NSFontManager.shared.availableMembers(ofFontFamily: familyName) else {
        print("No fonts found for family: \(familyName)")
        return []
    }

    var urls: [URL] = []

    for member in members {
        if let postscriptName = member[0] as? String,
            let font = NSFont(name: postscriptName, size: 12)
        {

            let ctFont = font as CTFont
            let descriptor = CTFontCopyFontDescriptor(ctFont)

            if let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL {
                urls.append(url)
            }
        }
    }

    if urls.isEmpty {
        print("Font file URLs not found for family: \(familyName)")
    }

    return urls
}

func revealFontsInFinder(urls: [URL]) {
    guard !urls.isEmpty else { return }

    NSWorkspace.shared.activateFileViewerSelecting(urls)
    for url in urls {
        print("Revealed font file: \(url.path)")
    }
}

func copyFontsToClipboard(urls: [URL]) {
    guard !urls.isEmpty else { return }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    let nsURLs = urls.map { $0 as NSURL }
    let success = pasteboard.writeObjects(nsURLs)

    if success {
        print("Copied \(urls.count) font file(s) to clipboard:")
        for url in urls {
            print("• \(url.path)")
        }
    } else {
        print("Failed to copy font files to clipboard.")
    }
}
