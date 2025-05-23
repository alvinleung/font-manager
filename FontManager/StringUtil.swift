//
//  StringUtil.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-23.
//

import Foundation

// Levenshtein distance function
func levenshtein(_ lhs: String, _ rhs: String) -> Int {
    let lhsChars = Array(lhs)
    let rhsChars = Array(rhs)
    let lhsCount = lhsChars.count
    let rhsCount = rhsChars.count

    // Handle empty strings first
    if lhsCount == 0 { return rhsCount }
    if rhsCount == 0 { return lhsCount }

    var matrix = Array(repeating: Array(repeating: 0, count: rhsCount + 1), count: lhsCount + 1)

    for i in 0...lhsCount { matrix[i][0] = i }
    for j in 0...rhsCount { matrix[0][j] = j }

    for i in 1...lhsCount {
        for j in 1...rhsCount {
            if lhsChars[i - 1] == rhsChars[j - 1] {
                matrix[i][j] = matrix[i - 1][j - 1]
            } else {
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + 1
                )
            }
        }
    }

    return matrix[lhsCount][rhsCount]
}

