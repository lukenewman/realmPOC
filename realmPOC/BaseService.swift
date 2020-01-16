//
//  BaseService.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import Foundation
import Deferred

class BaseService {

    enum Error: LocalizedError {
        case noData, httpError(statusCode: Int), offline

        var errorDescription: String? {
            switch self {
            case .noData:
                return NSLocalizedString("No data was returned from the server.", comment: "Error message when the server failed to return data.")
            case .httpError(let statusCode):
                let formatString = NSLocalizedString("The server returned an error. (status: %d)", comment: "Error message when the server fails with a non-200 status code.")
                return String(format: formatString, statusCode)
            case .offline:
                return NSLocalizedString("You are currently offline. Any updates made to playlists in the app will not be reflected in the Mac app until this app regains network connection.", comment: "Error message when the app is offline.")
            }
        }
    }

    static func networkTask<T: Decodable>(endpoint: API.Endpoint, parameters: [API.QueryParameters: String] = [:]) -> Task<T> {
        let deferred = Deferred<Task<T>.Result>()
        let session = URLSession(configuration: .default)

        guard var urlComponents = URLComponents(string: endpoint.urlString) else {
            preconditionFailure("Could not create URL from string: \(endpoint.urlString)")
        }

        if !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.rawValue, value: $1) }
        }

        guard let url = urlComponents.url else {
            preconditionFailure("Could not create URL from components: \(urlComponents)")
        }

        print("\(endpoint.method) \(endpoint) \(url)")

        let request = baseURLRequest(url: url, method: endpoint.method)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error?.localizedDescription != "cancelled" else { return }
            if let error = error {
                deferred.fail(with: error)
                return
            }
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                deferred.fail(with: Error.noData)
                return
            }
            guard httpResponse.statusCode == 200 else {
                deferred.fail(with: Error.httpError(statusCode: httpResponse.statusCode))
                return
            }

            do {
                let detail = try JSONDecoder().decode(T.self, from: data)
                deferred.succeed(with: detail)
            } catch {
                deferred.fail(with: error)
            }
        }

//        if Stores.shared.isOffline, endpoint.shouldCache {
//            Logger.log("caching task \(endpoint)", to: .offline)
//            Stores.shared.cachedTasks.append(task)
//            deferred.fail(with: Error.offline)
//        } else {
            task.resume()
//        }

        return Task(Future(deferred), uponCancel: {
            task.cancel()
        })
    }

    static func updateNetworkTask<T: Decodable, M: Encodable>(endpoint: API.Endpoint, body: M) -> Task<T> {
        let deferred = Deferred<Task<T>.Result>()
        let session = URLSession(configuration: .default)

        guard let urlComponents = URLComponents(string: endpoint.urlString) else {
            preconditionFailure("Could not create URL from string: \(endpoint.urlString)")
        }
        guard let url = urlComponents.url else {
            preconditionFailure("Could not create URL from components: \(urlComponents)")
        }

        guard let bodyData = try? JSONEncoder().encode(body) else {
            preconditionFailure("Could not encode body")
        }

        let jsonString = String(data: bodyData, encoding: .utf8) ?? "unable to get json"
        print("\(endpoint.method) \(endpoint) body=\(jsonString) \(url)")

        let request = baseURLRequest(url: url, method: endpoint.method)
        let task = session.uploadTask(with: request, from: bodyData) { (data, response, error) in
            if let error = error {
                deferred.fail(with: error)
                return
            }
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                deferred.fail(with: Error.noData)
                return
            }
            guard httpResponse.statusCode == 200 else {
                deferred.fail(with: Error.httpError(statusCode: httpResponse.statusCode))
                return
            }

            let decoder = JSONDecoder()
            do {
                let detail = try decoder.decode(T.self, from: data)
                deferred.succeed(with: detail)
            } catch {
                deferred.fail(with: error)
            }
        }

//        if Stores.shared.isOffline, endpoint.shouldCache {
//            Logger.log("caching task \(endpoint)", to: .offline)
//            Stores.shared.cachedTasks.append(task)
//            deferred.fail(with: Error.offline)
//        } else {
            task.resume()
//        }

        return Task(Future(deferred), uponCancel: {
            task.cancel()
        })
    }

    static func deleteNetworkTask(endpoint: API.Endpoint, parameters: [API.QueryParameters: String] = [:]) -> Task<Void> {
        let deferred = Deferred<Task<Void>.Result>()
        let session = URLSession(configuration: .default)

        guard var urlComponents = URLComponents(string: endpoint.urlString) else {
            preconditionFailure("Could not create URL from string: \(endpoint.urlString)")
        }

        if !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.rawValue, value: $1) }
        }

        guard let url = urlComponents.url else {
            preconditionFailure("Could not create URL from components: \(urlComponents)")
        }

        print("\(endpoint.method) \(endpoint) \(url)")

        let request = baseURLRequest(url: url, method: endpoint.method)
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                deferred.fail(with: error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                deferred.fail(with: Error.noData)
                return
            }
            guard httpResponse.statusCode == 200 else {
                deferred.fail(with: Error.httpError(statusCode: httpResponse.statusCode))
                return
            }

            deferred.succeed(with: ())
        }

//        if Stores.shared.isOffline, endpoint.shouldCache {
//            Logger.log("caching task \(endpoint)", to: .offline)
//            Stores.shared.cachedTasks.append(task)
//            deferred.fail(with: Error.offline)
//        } else {
            task.resume()
//        }

        return Task(Future(deferred), uponCancel: {
            task.cancel()
        })
    }

    static func baseURLRequest(url: URL, method: HTTPMethod) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-type")

        for (key, value) in API.shared.defaultHeader {
            request.addValue(value, forHTTPHeaderField: key)
        }

        return request
    }

}

