import Foundation
import Mockable

/// Result of executing a CLI command.
public struct CLIResult: Sendable, Equatable {
    public let output: String
    public let exitCode: Int32

    public init(output: String, exitCode: Int32 = 0) {
        self.output = output
        self.exitCode = exitCode
    }
}

/// Protocol for executing CLI commands - abstracts system interaction for testability.
/// From user's mental model: "Is this service available?" and "Get my stats"
@Mockable
public protocol CLIExecutor: Sendable {
    /// Locates a binary on the system. Returns the path if found, nil otherwise.
    func locate(_ binary: String) -> String?

    /// Executes a CLI command and returns the result.
    func execute(
        binary: String,
        args: [String],
        input: String?,
        timeout: TimeInterval,
        workingDirectory: URL?,
        sendOnSubstrings: [String: String]
    ) throws -> CLIResult
}

// MARK: - Default Implementation

/// Default CLIExecutor that uses BinaryLocator and InteractiveRunner.
public struct DefaultCLIExecutor: CLIExecutor {
    public init() {}

    public func locate(_ binary: String) -> String? {
        BinaryLocator.which(binary)
    }

    public func execute(
        binary: String,
        args: [String],
        input: String?,
        timeout: TimeInterval,
        workingDirectory: URL?,
        sendOnSubstrings: [String: String]
    ) throws -> CLIResult {
        let runner = InteractiveRunner()
        let options = InteractiveRunner.Options(
            timeout: timeout,
            workingDirectory: workingDirectory,
            arguments: args,
            autoResponses: sendOnSubstrings
        )

        let result = try runner.run(binary: binary, input: input ?? "", options: options)
        return CLIResult(output: result.output, exitCode: result.exitCode)
    }
}
