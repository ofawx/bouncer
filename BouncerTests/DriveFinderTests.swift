import Testing
@testable import Bouncer

struct DriveFinderTests {
    @Test(arguments: [
        ("disk4s2", "disk4"),
        ("disk12s1", "disk12"),
        ("disk4", "disk4"),
    ])
    func wholeDiskOfIdentifier(identifier: String, whole: String) {
        #expect(DriveFinder.wholeDisk(of: identifier) == whole)
    }

    @Test func apfsVolumeFollowsContainerToPhysicalDisk() {
        // From `diskutil info -plist` on an APFS volume on an external SSD:
        // the volume is disk5s1 in synthesized container disk5, backed by physical disk4.
        let info: [String: Any] = [
            "DeviceIdentifier": "disk5s1",
            "ParentWholeDisk": "disk5",
            "APFSPhysicalStores": [["APFSPhysicalStore": "disk4s2"]],
        ]
        #expect(DriveFinder.physicalDisks(fromInfo: info) == ["disk4"])
    }

    @Test func nonAPFSVolumeUsesItsParentDisk() {
        let info: [String: Any] = ["DeviceIdentifier": "disk8s2", "ParentWholeDisk": "disk8"]
        #expect(DriveFinder.physicalDisks(fromInfo: info) == ["disk8"])
    }

    @Test func missingInfoGivesNoDisks() {
        #expect(DriveFinder.physicalDisks(fromInfo: [:]).isEmpty)
    }
}
