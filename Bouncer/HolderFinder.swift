import Foundation

enum HolderFinder {
    struct Entry: Equatable {
        let pid: pid_t
        let command: String
        let isWorkingDirectory: Bool
    }

    /// Lists processes with files open on the volume. Without root, `lsof` only sees the current user's processes.
    static func holders(of volume: URL) async throws -> [Holder] {
        // -F pcf: machine-readable pid, command and file descriptor fields. -n -P: skip DNS and port lookups. -w: no warnings.
        let result = try await CommandRunner.run("/usr/sbin/lsof", ["-w", "-n", "-P", "-F", "pcf", "--", volume.path])

        // lsof exits 1 when nothing is open, which is the happy path.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return parse(result.output)
            .filter { $0.pid != ownPID }
            .map { entry in
                Holder(
                    pid: entry.pid,
                    command: entry.command,
                    executablePath: Holder.executablePath(of: entry.pid),
                    isWorkingDirectory: entry.isWorkingDirectory
                )
            }
    }

    /// Parses `lsof -F pcf` output. Each process starts with a `p` line, then `c`, then one `f` line per open file.
    static func parse(_ output: String) -> [Entry] {
        var entries: [Entry] = []
        var pid: pid_t?
        var command = ""
        var isWorkingDirectory = false

        func flush() {
            if let pid {
                entries.append(Entry(pid: pid, command: command, isWorkingDirectory: isWorkingDirectory))
            }
        }

        for line in output.split(separator: "\n") {
            guard let field = line.first else { continue }
            let value = line.dropFirst()
            switch field {
            case "p":
                flush()
                pid = pid_t(value)
                command = ""
                isWorkingDirectory = false
            case "c":
                command = String(value)
            case "f":
                if value == "cwd" { isWorkingDirectory = true }
            default:
                break
            }
        }
        flush()
        return entries
    }
}
