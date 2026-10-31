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
    /// System apps have translated names, like 写真 for Photos.app in Japanese.
    var enclosingAppName: String? {
        guard let components = executablePath?.split(separator: "/"),
              let index = components.firstIndex(where: { $0.hasSuffix(".app") })
        else { return nil }

        let bundle = Bundle(path: "/" + components[...index].joined(separator: "/"))
        return bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? String(components[index].dropLast(".app".count))
    }

    /// A plain-language name for what this process is. Shown mid-sentence ("In use by …"),
    /// so anything that isn't a proper noun stays lowercase.
    var label: String {
        if let known = Culprits.label(forExecutable: executableName) {
            return known
        }
        if isWorkingDirectory, Culprits.shells.contains(executableName) {
            return String(localized: "a terminal window", comment: "Follows \"In use by\", alone or in a list of app names.")
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

    /// Names match what macOS calls these features in each language.
    private static let labels: [String: String] = {
        let spotlight = String(localized: "Spotlight")
        let photos = String(localized: "Photos")
        let timeMachine = String(localized: "Time Machine")
        let quickLook = String(localized: "Quick Look")
        let iCloudDrive = String(localized: "iCloud Drive")

        return [
            "mds": spotlight,
            "mds_stores": spotlight,
            "mdworker": spotlight,
            "mdworker_shared": spotlight,
            "corespotlightd": spotlight,
            "managedcorespotlightd": spotlight,
            "photolibraryd": photos,
            "photoanalysisd": photos,
            "mediaanalysisd": photos,
            "cloudphotod": photos,
            "com.apple.CloudPhotosConfiguration": photos,
            "backupd": timeMachine,
            "backupd-helper": timeMachine,
            "quicklookd": quickLook,
            "QuickLookUIService": quickLook,
            "com.apple.quicklook.ThumbnailsAgent": quickLook,
            "bird": iCloudDrive,
            "fileproviderd": iCloudDrive,
        ]
    }()

    static func label(forExecutable name: String) -> String? {
        labels[name]
    }
}
