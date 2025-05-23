//
//  FontListView.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-22.
//

import Foundation
import SwiftUI
import CoreText

struct ColorMode {
    let name:String;
    let foreground: Color;
    let background: Color;
}

let modeDark = ColorMode(name: "dark", foreground: .white, background: .black)
let modeLight = ColorMode(name: "light", foreground: .black, background: .white)


func findFontFileURLs(familyName: String) -> [URL] {
    guard let members = NSFontManager.shared.availableMembers(ofFontFamily: familyName) else {
        print("No fonts found for family: \(familyName)")
        return []
    }

    var urls: [URL] = []

    for member in members {
        if let postscriptName = member[0] as? String,
           let font = NSFont(name: postscriptName, size: 12) {
            
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

struct FontView: View {
    let allFontFamily = NSFontManager.shared.availableFontFamilies
    
    @State private var searchText = ""
    @State private var demoText = "Handgloves"

    @State private var hoveredFont: String?
    @FocusState private var focusedFont: String?
    @State private var previewFontSize: CGFloat = 32
    
    @State private var colorMode:ColorMode = modeDark

//    var filteredFonts: [String] {
//        if searchText.isEmpty {
//            return allFontFamily
//        } else {
//            return allFontFamily.filter { $0.localizedCaseInsensitiveContains(searchText) }
//        }
//    }
    var filteredFonts: [String] {
        if searchText.isEmpty {
            return allFontFamily
        } else {
            let normalizedSearch = searchText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

            
//            let threshold = normalizedSearch.count / 3  // approx 33% of length allowed
            let threshold = max(2, normalizedSearch.count / 2)

            return allFontFamily.filter {
                let normalizedFont = $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

                if normalizedFont.contains(normalizedSearch) {
//                    print("Substring match: \(normalizedFont)")
                    return true
                }

                let distance = levenshtein(normalizedSearch, normalizedFont)
//                print("Comparing '\(normalizedSearch)' vs '\(normalizedFont)' => distance: \(distance)")

                return distance <= threshold
            }
        }
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                if colorMode.name == "dark" {
                    Image(systemName: "moon")
                    .onTapGesture {
                        colorMode = modeLight
                    }
                    .padding(4)
                }
                
                if colorMode.name == "light" {
                    Image(systemName: "sun.min")
                        .onTapGesture {
                            colorMode = modeDark
                        }.colorInvert().padding(4)
                }
            }
            .frame(height: 24)
//            .background(Color.red)
            .padding(EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 2))
            
            TextField("Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 24, weight: .light))
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .foregroundColor(colorMode.foreground)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredFonts, id: \.self) { name in
                        
                        // the list item
                        VStack(alignment: .leading, spacing: 4) {
                            
                            // the title
                            HStack (alignment:.center) {
                                Text(name)
                                    .font(.caption)
                                    .opacity(0.6)
                                Spacer()
                                
                                // controls
                                HStack {
                                    // copy font button
                                    Button(action: {
                                        // Reveal or copy all variants of the font
                                        let fontURLs = findFontFileURLs(familyName: name)
                                        
                                        if fontURLs.isEmpty {
                                            print("No font files found for family: \(name)")
                                        } else {
                                            copyFontsToClipboard(urls: fontURLs)
                                        }
                                        
                                    }) {
                                        let fileCount = findFontFileURLs(familyName: name).count
                                        Text("Copy \(fileCount) file\(fileCount > 1 ? "s":"") ").font(.caption)
                                    }.buttonStyle(AuxButtonStyle())
                                    
                                    // find font button
                                    Button(action: {
                                        // Reveal all font variants in Finder
                                        let fontURLs = findFontFileURLs(familyName: name)
                                        
                                        if fontURLs.isEmpty {
                                            print("No font files found for family: \(name)")
                                        } else {
                                            revealFontsInFinder(urls: fontURLs)
                                        }
                                    }) {
                                        Image(systemName: "folder")
                                    }.buttonStyle(AuxButtonStyle())
                                }
                                .opacity(hoveredFont == name ? 1 : 0)
                                .animation(.easeInOut(duration: 0.2), value: hoveredFont == name)
                            }
                            
                            // the preview
                            MultilineTextEditor(
                                text: $demoText,
                                placeholder: "Handgloves",
                                font: Font.custom(name, size: previewFontSize),
                                foregroundColor: colorMode.foreground,
                                backgroundColor: colorMode.background,
                                minHeight: previewFontSize
                            )
                            .focused($focusedFont, equals: name)
                        }
                        .padding(.bottom, 8)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedFont = name
                        }
                        .background(colorMode.background)
                        .foregroundColor(colorMode.foreground)
                        .onHover { hovering in
                            if hovering {
                                hoveredFont = name
                            }
                        }
                    }
                }
            }
            .onHover { hovering in
                if !hovering {hoveredFont = nil}
            }
            .background(colorMode.background)
        }
        .background(colorMode.background)
//        .toolbar {
//            ToolbarItemGroup(placement: .status, content: {
//                Spacer()
//                if colorMode.name == "dark" {
//                    Image(systemName: "moon")
//                    .onTapGesture {
//                        colorMode = modeLight
//                    }
//                }
//                
//                if colorMode.name == "light" {
//                    Image(systemName: "sun.min")
//                        .onTapGesture {
//                            colorMode = modeDark
//                        }.colorInvert()
//                }
//            })
//        }
    }
}


struct MultilineTextEditor: View {
    @Binding var text: String
    var placeholder: String = "Enter text..."
    var font: Font = .body
    var foregroundColor: Color = .primary
    var backgroundColor: Color = .clear
    var minHeight: CGFloat = 32

    var body: some View {
        ZStack(alignment: .topLeading) {

            TextEditor(text: $text)
                .font(font)
                .padding(0)
                .padding(.leading, -6)
                .padding(.vertical, 4)
                .scrollContentBackground(.hidden)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .scrollIndicators(.never)
                .cornerRadius(0)
            
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundColor(foregroundColor.opacity(0.3))
                    .padding(0)
                    .padding(.leading, -1)
                    .padding(.vertical, 4)
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
