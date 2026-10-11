import Testing
@testable import Bouncer

struct HolderFinderTests {
    @Test func parsesProcessesAndWorkingDirectories() {
        let output = """
        p438
        cloginwindow
        fcwd
        ftxt
        p14710
        cPhotos
        ftxt
        f6
        p900
        czsh
        fcwd

        """

        #expect(HolderFinder.parse(output) == [
            .init(pid: 438, command: "loginwindow", isWorkingDirectory: true),
            .init(pid: 14710, command: "Photos", isWorkingDirectory: false),
            .init(pid: 900, command: "zsh", isWorkingDirectory: true),
        ])
    }

    @Test func emptyOutputMeansNothingIsOpen() {
        #expect(HolderFinder.parse("").isEmpty)
    }

    @Test func keepsTruncatedCommandNames() {
        // lsof cuts long names short; the full name comes from the executable path instead.
        let entries = HolderFinder.parse("p11840\nccom.apple.CloudPhotosConfigurat\nftxt\n")
        #expect(entries.map(\.command) == ["com.apple.CloudPhotosConfigurat"])
    }
}
