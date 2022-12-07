// swiftlint:disable force_try

import XCTest
import Criollo

struct Person: Codable {
    let name: String
    let age: Int
}

class CriolloTest: XCTestCase {
    func runWebserver(port: Int, message: String) -> CRHTTPServer {
        let server = CRHTTPServer()
        server.get("/") { (req, res, next) in
            Task {
                try await Task.sleep(nanoseconds: UInt64(1 * SECOND))
                res.send(message)
            }
        }
        server.post("/") { (req, res, next) in
            let data = try! JSONSerialization.data(withJSONObject: req.body!, options: [])
            let person = try! JSONDecoder().decode(Person.self, from: data)
            XCTAssertEqual(person.name, "John")
            XCTAssertEqual(person.age, 42)
            res.send(data)
        }

        var serverError: NSError?
        print("starting server on port \(port)")
        server.startListening(&serverError, portNumber: UInt(port))

        return server
    }

    func testWebserver() async throws {
        let server = runWebserver(port: 8080, message: "Hello, world!")
        let server2 = runWebserver(port: 8081, message: "Hello, world in another server!")
        XCTAssertEqual(server.isSecure, false)
        XCTAssertEqual(server2.isSecure, false)

        // Test GET
        let (message, _) = try await URLSession.shared.data(from: URL(string: "http://localhost:8080")!)
        XCTAssertEqual(String(data: message, encoding: .utf8), "Hello, world!")
        let (message2, _) = try await URLSession.shared.data(from: URL(string: "http://localhost:8081")!)
        XCTAssertEqual(String(data: message2, encoding: .utf8), "Hello, world in another server!")

        // Test POST
        var request = URLRequest(url: URL(string: "http://localhost:8080")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(Person(name: "John", age: 42))
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.data(for: request)
        let person = try JSONDecoder().decode(Person.self, from: data)
        XCTAssertEqual(person.name, "John")
        XCTAssertEqual(person.age, 42)
    }
}
