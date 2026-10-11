import AppKit
import Darwin

/// A process with something open on a volume.
struct Holder: Identifiable, Hashable {
    let pid: pid_t
    /// The process name as `lsof` reports it, which may be cut short.
    let command: String
    /// Full path to the executable, when we're allowed to see it.
    let executablePath: String?
    /// True when the process's working directory is on the volume, like a Terminal tab `cd`'d into it.
    let isWorkingDirectory: Bool

    var id: pid_t { pid }

    /// Processes running in a Terminal window, like a shell or an editor, are left alone: stopping them could lose work.
    var canBeStopped: Bool {
        !Holder.hasTerminal(pid)
    }

    var executableName: String {
        executablePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? command
    }

    /// The name of the outermost app bundle the executable lives in, so helpers group under their app.
    var enclosingAppName: String? {
        guard let path = executablePath,
              let app = path.split(separator: "/").first(where: { $0.hasSuffix(".app") })
        else { return nil }
        return String(app.dropLast(".app".count))
    }

    /// A plain-English name for what this process is. Shown mid-sentence ("In use by …"),
    /// so anything that isn't a proper noun stays lowercase.
    var label: String {
        if let known = Culprits.label(forExecutable: executableName) {
            return known
        }
        if isWorkingDirectory, Culprits.shells.contains(executableName) {
            return "a terminal window"
        }
        if let app = enclosingAppName {
            return app
        }
        if let name = NSRunningApplication(processIdentifier: pid)?.localizedName {
            return name
        }
        return executableName
    }

    static func hasTerminal(_ pid: pid_t) -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return false }
        return info.kp_eproc.e_tdev != -1
    }

    static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(cString: buffer) : nil
    }
}

enum Culprits {
    static let shells: Set<String> = ["zsh", "bash", "fish", "sh", "tcsh", "ksh", "dash"]

    private static let labels: [String: String] = [
        "mds": "Spotlight",
        "mds_stores": "Spotlight",
        "mdworker": "Spotlight",
        "mdworker_shared": "Spotlight",
        "corespotlightd": "Spotlight",
        "managedcorespotlightd": "Spotlight",
        "photolibraryd": "Photos",
        "photoanalysisd": "Photos",
        "mediaanalysisd": "Photos",
        "cloudphotod": "Photos",
        "com.apple.CloudPhotosConfiguration": "Photos",
        "backupd": "Time Machine",
        "backupd-helper": "Time Machine",
        "quicklookd": "Quick Look",
        "QuickLookUIService": "Quick Look",
        "com.apple.quicklook.ThumbnailsAgent": "Quick Look",
        "bird": "iCloud Drive",
        "fileproviderd": "iCloud Drive",
    ]

    static func label(forExecutable name: String) -> String? {
        labels[name]
    }
}
