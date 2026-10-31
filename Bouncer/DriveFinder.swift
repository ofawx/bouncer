import Foundation

enum DriveFinder {
    private static let resourceKeys: [URLResourceKey] = [
        .volumeNameKey,
        .volumeIsInternalKey,
        .volumeIsEjectableKey,
        .volumeIsRemovableKey,
        .volumeIsLocalKey,
    ]

    /// External drives and disk images, each with the visible volumes mounted from it.
    static func drives() async -> [ExternalDrive] {
        let startupDisks = Set((try? await physicalDisks(of: "/")) ?? [])

        var volumesByDisk: [String: [ExternalVolume]] = [:]
        for volume in externalVolumes() {
            // A volume can span several physical disks (Fusion Drives), but external ones almost never do.
            guard let disk = try? await physicalDisks(of: volume.url.path).first else { continue }
            volumesByDisk[disk, default: []].append(volume)
        }

        var drives: [ExternalDrive] = []
        for (disk, volumes) in volumesByDisk {
            drives.append(ExternalDrive(
                id: disk,
                name: await name(ofDisk: disk),
                isStartupDisk: startupDisks.contains(disk),
                volumes: volumes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            ))
        }
        return drives.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Visible local volumes that aren't on an internal disk. Many external SSDs report themselves as
    /// neither ejectable nor removable, so "not internal" does most of the work.
    static func externalVolumes() -> [ExternalVolume] {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(resourceKeys)),
                  values.volumeIsLocal == true
            else { return nil }

            let isExternal = values.volumeIsInternal == false
                || values.volumeIsEjectable == true
                || values.volumeIsRemovable == true
            guard isExternal else { return nil }

            return ExternalVolume(url: url, name: values.volumeName ?? url.lastPathComponent)
        }
    }

    /// The physical whole disks a volume lives on. APFS volumes sit in a synthesized container disk,
    /// so we follow the container back to its physical store.
    static func physicalDisks(of target: String) async throws -> [String] {
        physicalDisks(fromInfo: try await info(target))
    }

    static func physicalDisks(fromInfo info: [String: Any]) -> [String] {
        if let stores = info["APFSPhysicalStores"] as? [[String: Any]], !stores.isEmpty {
            return stores.compactMap { ($0["APFSPhysicalStore"] as? String).map(wholeDisk) }
        }
        if let parent = info["ParentWholeDisk"] as? String {
            return [wholeDisk(of: parent)]
        }
        return []
    }

    /// "disk4s2" → "disk4".
    static func wholeDisk(of identifier: String) -> String {
        guard let range = identifier.range(of: #"^disk\d+"#, options: .regularExpression) else {
            return identifier
        }
        return String(identifier[range])
    }

    private static func name(ofDisk disk: String) async -> String {
        let fallback = String(localized: "External Drive")
        guard let info = try? await info(disk) else { return fallback }

        if info["BusProtocol"] as? String == "Disk Image" {
            return (try? await diskImageName(of: disk)) ?? String(localized: "Disk Image")
        }

        let mediaName = (info["MediaName"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        return mediaName.isEmpty ? fallback : mediaName
    }

    /// The file name of the disk image mounted at this disk, such as "Installer.dmg".
    private static func diskImageName(of disk: String) async throws -> String? {
        let result = try await CommandRunner.run("/usr/bin/hdiutil", ["info", "-plist"])
        let plist = try PropertyListSerialization.propertyList(from: Data(result.output.utf8), format: nil)
        let images = (plist as? [String: Any])?["images"] as? [[String: Any]] ?? []

        for image in images {
            let entities = image["system-entities"] as? [[String: Any]] ?? []
            if entities.contains(where: { $0["dev-entry"] as? String == "/dev/\(disk)" }),
               let path = image["image-path"] as? String {
                return URL(fileURLWithPath: path).lastPathComponent
            }
        }
        return nil
    }

    private static func info(_ target: String) async throws -> [String: Any] {
        let result = try await CommandRunner.run("/usr/sbin/diskutil", ["info", "-plist", target])
        let plist = try PropertyListSerialization.propertyList(from: Data(result.output.utf8), format: nil)
        return plist as? [String: Any] ?? [:]
    }
}
