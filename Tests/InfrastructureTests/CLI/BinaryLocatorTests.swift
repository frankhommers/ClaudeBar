import Testing
import Foundation
@testable import Infrastructure

@Suite
struct BinaryLocatorTests {

    @Test
    func `which finds system binary`() {
        let path = BinaryLocator.which("ls")
        #expect(path != nil)
        #expect(path?.hasSuffix("/ls") == true)
    }

    @Test
    func `which returns nil for unknown binary`() {
        let path = BinaryLocator.which("unknown-binary-xyz-123")
        #expect(path == nil)
    }

    @Test
    func `locate instance method finds binary`() {
        let locator = BinaryLocator()
        let path = locator.locate("ls")
        #expect(path != nil)
    }
}