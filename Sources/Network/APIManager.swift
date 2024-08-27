//
//  File.swift
//  
//
//  Created by Ricardo Bailoni on 25/08/24.
//

import Foundation
import NetworkProtocols
import Combine
import Errors

public final class APIManager: ManagerProtocol {
    typealias NetworkResponse = (data: Data, response: URLResponse)
    typealias Failure = APIError
    
    public static let shared: ManagerProtocol = APIManager()
    private init() { }
    
    private let session = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cancellable = Set<AnyCancellable>()
    
    public func data<D: Decodable>(from endpoint: EndPointProtocol, completion: @escaping (Result<D, APIError>) -> Void) {
        guard let request = try? createRequest(from: endpoint) else {
            completion(.failure(.request))
            return
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.reponse(error)))
                return
            }
            
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                completion(.failure(.statusCode(response)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            do {
                let resultData = try JSONDecoder().decode(D.self, from: data)
                completion(.success(resultData))
            } catch {
                completion(.failure(.decoding))
            }
        }.resume()
    }
    
    public func data<D: Decodable>(from endpoint: EndPointProtocol) -> AnyPublisher<D, Error> {
        guard let request = try? createRequest(from: endpoint) else {
            return Fail(error: APIError.request).eraseToAnyPublisher()
        }
        return session.dataTaskPublisher(for: request)
            .tryMap { (data, response) -> Data in
                guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                    throw APIError.statusCode(response)
                }
                return data
            }
            .decode(type: D.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    public func data<D: Decodable>(from endpoint: EndPointProtocol) async throws -> D {
        let request = try createRequest(from: endpoint)
        let response: NetworkResponse = try await session.data(for: request)
        return try decoder.decode(D.self, from: response.data)
    }
}

private extension APIManager {
    func createRequest(from endpoint: EndPointProtocol) throws -> URLRequest {
        guard let urlPath = URL(string: endpoint.baseURL.appending(endpoint.path)),
              var urlComponents = URLComponents(url: urlPath, resolvingAgainstBaseURL: true)
        else {
            throw APIError.path
        }
        
        if let queries = endpoint.queries {
            urlComponents.queryItems = queries
        }
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        if let headers = endpoint.headers {
            headers.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if endpoint.body.isEmpty == false {
            for (header, value) in endpoint.body.additionalHeaders {
                request.addValue(value, forHTTPHeaderField: header)
            }
        }
        
        request.httpBody = try endpoint.body.encode()
        
        return request
    }
}
