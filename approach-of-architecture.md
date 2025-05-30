

## Approach for structuring the app


## Rely on CTFontManager

Instead of building my own database for this, I should be relying on macos'
core text font manager (CTFontManager). It has built in function for
registering and unregistering font, even for temporarily installing a font for
preview so it really has no reason for me to save a bunch of font metadata on a
database.


## Font Provider Abstraction

This is for the case where we allow user to install font from providers like
Google Font or have a specific folder that they want to watch. The plan is to
support:

- Custom Watch Folder
- Google Font

```swift

protocol FontFamilyPreviewInfo {
    let fmaily: String
    let fontFiles: [String]
    // ...
}

protocol FontProvider<T> { 
    // fetch all the metadata related the font
    func fetchAvailable() async -> [T]

    // install the font from the source, meaning, 
    // copying it from the source to the user's 
    // font folder ~/Library/font
    func install(font:T) async
}
```



## Google font api

(Google Font API)[https://developers.google.com/fonts/docs/developer_api]

