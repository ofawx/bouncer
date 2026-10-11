import AppKit

@MainActor
final class VolumeStore: ObservableObject {
    enum EjectState: Equatable {
        case idle
        case ejecting
        case failed(String)
    }

    @Published private(set) var drives: [ExternalDrive] = []
    @Published private(set) var holders: [ExternalVolume.ID: [Holder]] = [:]
    /// Processes diskutil named when it refused to eject. These can be root processes `lsof` can't see.
    @Published private(set) var dissenters: [ExternalDrive.ID: [Holder]] = [:]
    @Published private(set) var ejectStates: [ExternalDrive.ID: EjectState] = [:]

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
        }
        Task { await refresh() }
    }

    deinit {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }

    func refresh() async {
        drives = await DriveFinder.drives()

        let driveIDs = Set(drives.map(\.id))
        let volumeIDs = Set(drives.flatMap(\.volumes).map(\.id))
        holders = holders.filter { volumeIDs.contains($0.key) }
        dissenters = dissenters.filter { driveIDs.contains($0.key) }
        ejectStates = ejectStates.filter { driveIDs.contains($0.key) }

        await refreshHolders()
    }

    func refreshHolders() async {
        for volume in drives.flatMap(\.volumes) {
            if let found = try? await HolderFinder.holders(of: volume.url) {
                holders[volume.id] = found
            }
        }
    }

    func ejectState(of drive: ExternalDrive) -> EjectState {
        ejectStates[drive.id] ?? .idle
    }

    /// Holder names for display, with helper processes folded into their app.
    func holderLabels(of volume: ExternalVolume) -> [String] {
        uniqueLabels(holders[volume.id] ?? [])
    }

    func holderLabels(of drive: ExternalDrive) -> [String] {
        uniqueLabels(holders(of: drive))
    }

    /// Tries to eject. When something refuses, stops whatever is holding the drive and tries again.
    func eject(_ drive: ExternalDrive) async {
        guard !drive.isStartupDisk else { return }

        ejectStates[drive.id] = .ejecting
        dissenters[drive.id] = nil
        do {
            for attempt in 1...Self.ejectAttempts {
                switch try await Ejector.eject(drive) {
                case .ejected:
                    ejectStates[drive.id] = nil
                    return
                case .refused(let dissenter, _):
                    await refreshHolders()
                    dissenters[drive.id] = dissenter.map { [holder(for: $0)] }

                    let stoppable = holders(of: drive).filter(\.canBeStopped)
                    guard attempt < Self.ejectAttempts, !stoppable.isEmpty else {
                        ejectStates[drive.id] = .failed(failureMessage(for: drive))
                        return
                    }
                    await Ejector.stop(stoppable)
                }
            }
        } catch {
            ejectStates[drive.id] = .failed("Couldn't eject \(drive.name).")
        }
    }

    private static let ejectAttempts = 3

    /// Everything known to be using the drive, once per process.
    private func holders(of drive: ExternalDrive) -> [Holder] {
        var seen = Set<pid_t>()
        let all = drive.volumes.flatMap { holders[$0.id] ?? [] } + (dissenters[drive.id] ?? [])
        return all.filter { seen.insert($0.pid).inserted }
    }

    private func holder(for dissenter: Ejector.Dissenter) -> Holder {
        let path = dissenter.path ?? Holder.executablePath(of: dissenter.pid)
        return Holder(
            pid: dissenter.pid,
            command: path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "PID \(dissenter.pid)",
            executablePath: path,
            isWorkingDirectory: false
        )
    }

    private func uniqueLabels(_ holders: [Holder]) -> [String] {
        var seen = Set<String>()
        return holders.map(\.label).filter { seen.insert($0).inserted }
    }

    private func failureMessage(for drive: ExternalDrive) -> String {
        let names = holderLabels(of: drive)
        guard !names.isEmpty else {
            return "Couldn't eject. Something is still using it."
        }
        return "Couldn't eject. It's being used by \(ListFormatter.localizedString(byJoining: names))."
    }
}
