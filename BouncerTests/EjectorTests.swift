import Testing
@testable import Bouncer

struct EjectorTests {
    @Test func findsDissenterInRealDiskutilOutput() {
        // Captured from `diskutil eject` on a disk image with a shell cd'd into one of its volumes.
        let message = """
        Unmount of disk6 failed: at least one volume could not be unmounted
        Unmount was dissented by PID 19740 (/bin/sleep)
        Dissenter parent PPID 19669 (/bin/zsh)
        """

        #expect(Ejector.dissenter(in: message) == .init(pid: 19740, path: "/bin/sleep"))
    }

    @Test func findsDissenterWithoutPath() {
        let message = "Volume Archive on disk5s1 failed to unmount: dissented by PID 77"
        #expect(Ejector.dissenter(in: message) == .init(pid: 77, path: nil))
    }

    @Test func noDissenterInUnrelatedErrors() {
        #expect(Ejector.dissenter(in: "Unable to find disk for disk9") == nil)
    }
}
