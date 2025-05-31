enum FontStatus {
    case active
    case intactive
    case notInstalled
}

struct FontResolutionResult {
    var status: FontStatus
}

struct FontResolver {
    /*
    
    This function look up all the available sources: system, google font
    sync dir and deterimine what is needed to
    
    */
    static func resolve(family: String) {

    }
}
