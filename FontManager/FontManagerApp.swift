import CoreText
import SwiftData
import SwiftUI

@main
struct FontManagerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FontFamily.self,
            FontFile.self,
            AppUserPreferences.self,
        ])
        let appDataModelConfig = ModelConfiguration(
            "NewModel3",
            schema: schema,
            isStoredInMemoryOnly: false  // comment out in production
        )

        do {
            return try ModelContainer(for: schema, configurations: appDataModelConfig)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject var fontPreviewState = FontPreviewState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 400, minHeight: 600)
                .edgesIgnoringSafeArea(.top)
                .environmentObject(fontPreviewState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Sync Folder") {
                    Task {
                        await FontSync.syncWithPermission()
                    }
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])

                Button("Fetch Google Font") {
                    Task {
                        let res = await GoogleFontProvider.shared.fetchAvailable()
                        guard case let .success(googleFonts) = res else {
                            if case let .failure(err) = res {
                                print("Error: \(err)")
                            } else {
                                print("unkown error")
                            }
                            return
                        }

                    }
                }
                .keyboardShortcut("G", modifiers: [.command, .shift])
            }
            FontPreviewCommands(state: fontPreviewState)
        }
    }
}

struct MainView: View {
    @Environment(\.modelContext) private var context

    @Query private var preferencesList: [AppUserPreferences]

    @State private var indexingProgress: Double = 0.0  // from 0.0 to 1.0

    @Query(sort: \FontFamily.name)  // Fetch all FontFamily sorted by name
    private var allFontFamilies: [FontFamily]

    var body: some View {
        ZStack {
            let preferences = preferencesList.first ?? AppUserPreferences()
            FontView(
                allFonts: allFontFamilies,
                loadingProgress: indexingProgress,
                onRefreshDB: {
                    print("clicked refresh db")
                    guard indexingProgress != 0 else { return }
                    indexingProgress = 0
                    Task {
                        print("clearing database...")
                        await clearDatabase()
                        await initializeDataIfNeeded { progress in
                            indexingProgress = progress
                        }
                    }
                },
                preferences: preferences,
                context: context,
                demoText: preferences.demoText
            )
            .onAppear {
                // Insert new preference if new
                if preferencesList.isEmpty {
                    context.insert(preferences)
                    try? context.save()
                }
            }
        }
        .task {
            await initializeDataIfNeeded { progress in
                indexingProgress = progress
            }
        }
    }

    @MainActor
    private func clearDatabase() async {
        do {
            let families = try context.fetch(FetchDescriptor<FontFamily>())
            for family in families {
                context.delete(family)
            }

            let files = try context.fetch(FetchDescriptor<FontFile>())
            for file in files {
                context.delete(file)
            }

            let prefs = try context.fetch(FetchDescriptor<AppUserPreferences>())
            for pref in prefs {
                context.delete(pref)
            }

            try context.save()
            print("Database cleared.")
        } catch {
            print("Failed to clear database: \(error)")
        }
    }

    @MainActor
    private func initializeDataIfNeeded(progressUpdate: @escaping (Double) -> Void) async {
        // Skip if already populated
        let existingFamilies: [FontFamily]
        do {
            existingFamilies = try context.fetch(FetchDescriptor<FontFamily>())
        } catch {
            print("Failed to fetch: \(error)")
            progressUpdate(1)
            return
        }

        guard existingFamilies.isEmpty else {
            print("Database is not empty, skipping font indexing.")
            progressUpdate(1)
            return
        }

        print("Starting concurrent font metadata fetching...")

        let fontFamilyNames = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        let totalCount = fontFamilyNames.count

        var fetchedResults = [SystemFontData]()
        fetchedResults.reserveCapacity(totalCount)

        // Fetch in parallel
        await withTaskGroup(of: SystemFontData?.self) { group in
            for familyName in fontFamilyNames {
                group.addTask {
                    return fetchSingleFontFamily(familyName: familyName)
                }
            }

            var completed = 0
            for await result in group {
                if let data = result {
                    fetchedResults.append(data)
                }
                completed += 1
                progressUpdate(Double(completed) / Double(totalCount) * 0.5)  // 50% for fetch
            }
        }

        print("Inserting font data into model...")

        // Insert on main actor in batches
        let totalFamilies = fetchedResults.count
        for (index, systemFontData) in fetchedResults.enumerated() {
            let family = FontFamily(
                name: systemFontData.familyName, category: systemFontData.category.rawValue,
                source: "system", )

            for fileData in systemFontData.files {
                let file = FontFile(
                    style: fileData.style,
                    weight: fileData.weight,
                    italic: fileData.italic,
                    source: "system",
                    path: URL(fileURLWithPath: fileData.path),
                    originPath: nil,
                    format: fileData.format
                )
                file.family = family
                family.files.append(file)
            }

            context.insert(family)

            // Save every N inserts or at the end
            if index % 10 == 0 || index == totalFamilies - 1 {
                do {
                    try context.save()
                } catch {
                    print("Error saving context: \(error)")
                }
            }

            progressUpdate(0.5 + (Double(index + 1) / Double(totalFamilies) * 0.5))  // second 50%
        }

        print("All system fonts indexed.")
    }
}
// MARK: - Plain data structs used off main actor

struct SystemFontData {
    let familyName: String
    let category: FontCategoryInfo
    let files: [SystemFontFileData]
}

struct SystemFontFileData {
    let style: String
    let weight: Int
    let italic: Bool
    let format: String
    let path: String
}

enum FontCategoryInfo: String {
    case serif
    case sansSerif
    case monospaced
    case unknown
}

// MARK: - System Font Fetcher

func fetchSingleFontFamily(familyName: String) -> SystemFontData? {
    var files = [SystemFontFileData]()
    var category: FontCategoryInfo = .unknown

    let attributes: [CFString: Any] = [kCTFontFamilyNameAttribute: familyName]
    let desc = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)

    guard
        let matches = CTFontDescriptorCreateMatchingFontDescriptors(desc, nil)
            as? [CTFontDescriptor]
    else {
        return nil
    }

    for match in matches {
        let ctFont = CTFontCreateWithFontDescriptor(match, 0.0, nil)
        let fontName = CTFontCopyName(ctFont, kCTFontStyleNameKey) as String? ?? "Regular"
        let traits = CTFontCopyTraits(ctFont) as NSDictionary
        let weight = traits[kCTFontWeightTrait] as? Double ?? 0.0
        let symbolicTraits = CTFontGetSymbolicTraits(ctFont)
        let isItalic = symbolicTraits.contains(.traitItalic)

        let fontPath =
            (CTFontDescriptorCopyAttribute(match, kCTFontURLAttribute) as? URL)?.path ?? ""

        if category == .unknown {
            category = inferCategoryFromFontName(familyName, traits: symbolicTraits)
        }

        files.append(
            SystemFontFileData(
                style: fontName,
                weight: Int((weight * 1000).rounded()),
                italic: isItalic,
                format: "system",
                path: fontPath
            ))
    }

    return SystemFontData(familyName: familyName, category: category, files: files)
}

func inferCategoryFromFontName(_ name: String, traits: CTFontSymbolicTraits) -> FontCategoryInfo {
    if traits.contains(.traitMonoSpace) {
        return .monospaced
    }

    let lower = name.lowercased()
    if lower.contains("serif") { return .serif }
    if lower.contains("sans") || lower.contains("helvetica") || lower.contains("arial") {
        return .sansSerif
    }

    return .unknown
}
