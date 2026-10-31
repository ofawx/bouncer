import AppKit

enum Ejector {
    struct Dissenter: Equatable {
        let pid: pid_t
        let path: String?
    }

    enum Outcome: Equatable {
        case ejected
        case refused(dissenter: Dissenter?, message: String)
    }

    /// Unmounts every volume on the drive, then ejects it.
    static func eject(_ drive: ExternalDrive) async throws -> Outcome {
        let result = try await CommandRunner.run("/usr/sbin/diskutil", ["eject", drive.id])
        if result.status == 0 {
            return .ejected
        }
        let message = (result.error + result.output).trimmingCharacters(in: .whitespacesAndNewlines)
        return .refused(dissenter: dissenter(in: message), message: message)
    }

    /// Mounts the drive's volumes again. `diskutil` unmounts all it can before refusing,
    /// so a refused eject can leave some of them unmounted.
    static func remount(_ drive: ExternalDrive) async throws {
        _ = try await CommandRunner.run("/usr/sbin/diskutil", ["mountDisk", drive.id])
    }

    /// Pulls the blocking process out of a failed `diskutil` message, such as
    /// "Unmount was dissented by PID 412 (/System/Library/.../mds)". This sees root processes that `lsof` can't.
    static func dissenter(in message: String) -> Dissenter? {
        let pattern = #"dissented by PID (\d+)(?: \(([^)]+)\))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              let pidRange = Range(match.range(at: 1), in: message),
              let pid = pid_t(message[pidRange])
        else { return nil }

        let path = Range(match.range(at: 2), in: message).map { String(message[$0]) }
        return Dissenter(pid: pid, path: path)
    }

    /// Asks each holder to stop: apps quit as if you chose Quit from their menu, background processes get SIGTERM.
    /// Returns once they've all exited or `timeout` passes.
    static func stop(_ holders: [Holder], timeout: Duration = .seconds(5)) async {
        let signalled = holders.filter { holder in
            if let app = NSRunningApplication(processIdentifier: holder.pid), app.activationPolicy == .regular {
                return app.terminate()
            }
            return kill(holder.pid, SIGTERM) == 0
        }

        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline, signalled.contains(where: { kill($0.pid, 0) == 0 }) {
            try? await Task.sleep(for: .milliseconds(250))
        }
    }
}
