import Testing
import Foundation
@testable import Infrastructure

@Suite
struct InteractiveRunnerTests {

    @Test
    func `run executes command and returns output`() throws {
        let runner = InteractiveRunner()
        let result = try runner.run(
            binary: "echo",
            input: "",
            options: .init(arguments: ["hello"])
        )

        #expect(result.exitCode == 0)
        #expect(result.output.contains("hello"))
    }

    @Test
    func `run throws when binary not found`() {
        let runner = InteractiveRunner()
        #expect(throws: InteractiveRunner.RunError.self) {
            try runner.run(binary: "unknown-binary-xyz-123", input: "")
        }
    }
}