import Foundation

struct CommandResult {
    let status: Int32
    let output: String
    let error: String
}

enum CommandRunner {
    /// Runs a command off the main thread and collects its output.
    static func run(_ path: String, _ arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments

                let output = Pipe()
                let error = Pipe()
                process.standardOutput = output
                process.standardError = error

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                // Read before waiting so a full pipe can't stall the process.
                let outputData = output.fileHandleForReading.readDataToEndOfFile()
                let errorData = error.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                continuation.resume(returning: CommandResult(
                    status: process.terminationStatus,
                    output: String(decoding: outputData, as: UTF8.self),
                    error: String(decoding: errorData, as: UTF8.self)
                ))
            }
        }
    }
}
