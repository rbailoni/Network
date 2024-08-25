//
//  File.swift
//  
//
//  Created by Ricardo Bailoni on 25/08/24.
//

import Foundation

public enum APIError: Error {
    case path
    case request
    case reponse(Error)
    case statusCode(URLResponse?)
    case decoding
    case noData
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .path:
            return "Invalid Path"
        case .decoding:
            return "There was an error decoding the type"
        case .request:
            return "Invalid Reques"
        case .reponse(_):
            return "Invalid Response"
        case .statusCode(let response):
            return "Invalid StatusCode: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
        case .noData:
            return "No Data returned"
        }
    }
}
