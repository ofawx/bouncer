import Foundation
import Testing
@testable import Bouncer

struct HolderLabelTests {
    // PIDs here are made up and won't match a running app, so labels come from the path alone.
    private func holder(_ path: String, cwd: Bool = false) -> Holder {
        Holder(
            pid: 999_999,
            command: URL(fileURLWithPath: path).lastPathComponent,
            executablePath: path,
            isWorkingDirectory: cwd
        )
    }

    @Test(arguments: [
        ("/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Support/mds", "Spotlight"),
        ("/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", "Spotlight"),
        ("/System/Library/PrivateFrameworks/PhotoLibraryServices.framework/Versions/A/Support/photolibraryd", "Photos"),
        ("/usr/libexec/cloudphotod", "Photos"),
        ("/System/Library/CoreServices/backupd.bundle/Contents/Resources/backupd", "Time Machine"),
        ("/usr/bin/quicklookd", "Quick Look"),
    ])
    func knownSystemProcesses(path: String, label: String) {
        #expect(holder(path).label == label)
    }

    @Test func helpersGroupUnderTheirApp() {
        let helper = holder("/System/Applications/Photos.app/Contents/XPCServices/x.xpc/Contents/MacOS/com.apple.CloudPhotosConfiguration")
        #expect(helper.label == "Photos")

        let nested = holder("/Applications/Final Cut Pro.app/Contents/PlugIns/Helper.app/Contents/MacOS/Helper")
        #expect(nested.label == "Final Cut Pro")
    }

    @Test func shellInsideTheDriveIsATerminalWindow() {
        #expect(holder("/bin/zsh", cwd: true).label == "a terminal window")
    }

    @Test func shellNotInsideTheDriveIsJustTheShell() {
        // A shell with a file open on the drive, but its working directory elsewhere.
        #expect(holder("/bin/zsh").label == "zsh")
    }

    @Test func unknownProcessesFallBackToTheirName() {
        #expect(holder("/usr/libexec/somethingd").label == "somethingd")
    }

    /// Labels always follow "In use by", so only proper nouns are capitalised, wherever they land in the list.
    @Test(arguments: [
        (["Photos", "a terminal window"], "Photos and a terminal window"),
        (["a terminal window", "Photos"], "a terminal window and Photos"),
        (["Photos", "a terminal window", "Spotlight"], "Photos, a terminal window, and Spotlight"),
    ])
    func labelsReadNaturallyInAList(labels: [String], expected: String) {
        let formatter = ListFormatter()
        formatter.locale = Locale(identifier: "en_US")
        #expect(formatter.string(from: labels) == expected)
    }
}
