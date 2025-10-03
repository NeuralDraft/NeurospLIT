// MockURLProtocol.swift
// Testing utilities for network mocking
// Copyright © 2025 NeurospLIT. All rights reserved.

import Foundation

/// Mock URL Protocol for testing network requests
final class MockURLProtocol: URLProtocol {
    /// Handler for intercepting and mocking requests
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {
        // No cleanup needed for mock protocol
    }
}

// MARK: - Test Helpers

extension MockURLProtocol {
    /// Configure URLSession for testing with mock protocol
    static func createMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
    
    /// Reset mock handler
    static func reset() {
        requestHandler = nil
    }
    
    /// Mock a successful JSON response
    static func mockJSONResponse<T: Encodable>(
        _ object: T,
        statusCode: Int = 200,
        headers: [String: String] = ["Content-Type": "application/json"]
    ) throws -> (HTTPURLResponse, Data) {
        let data = try JSONEncoder().encode(object)
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
        return (response, data)
    }
}