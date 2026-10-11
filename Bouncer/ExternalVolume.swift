import Foundation

/// A mounted volume, such as one partition or APFS volume on a drive.
struct ExternalVolume: Identifiable, Hashable {
    let url: URL
    let name: String

    var id: URL { url }
}

/// A physical drive or disk image. Ejecting it unmounts every volume on it.
struct ExternalDrive: Identifiable, Hashable {
    /// The whole-disk BSD name, such as "disk4".
    let id: String
    let name: String
    /// True when the Mac is running from this drive, so it can't be ejected.
    let isStartupDisk: Bool
    var volumes: [ExternalVolume]
}
