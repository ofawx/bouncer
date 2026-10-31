import SwiftUI
import Sparkle

struct MenuContentView: View {
    @ObservedObject var store: VolumeStore
    @ObservedObject var loginItem: LoginItem
    let updater: SPUUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.drives.isEmpty {
                Text("No drives to eject")
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(store.drives) { drive in
                    DriveSection(store: store, drive: drive)
                }
            }

            Divider()
                .padding(.vertical, 4)

            Group {
                Toggle("Start at Login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                .toggleStyle(.checkbox)

                CheckForUpdatesView(updater: updater)

                Button("Quit Bouncer") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 6)
        .frame(width: 320)
        .task {
            loginItem.refresh()
            await store.refreshHolders()
        }
    }
}

private struct DriveSection: View {
    @ObservedObject var store: VolumeStore
    let drive: ExternalDrive

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "externaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(drive.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    status
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                ejectButton
            }

            ForEach(drive.volumes) { volume in
                VolumeRow(store: store, volume: volume)
                    .padding(.leading, 34)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var status: some View {
        if drive.isStartupDisk {
            Text("Your Mac is running from this drive")
                .foregroundStyle(.secondary)
        } else {
            switch store.ejectState(of: drive) {
            case .failed(let message):
                Text(message)
                    .foregroundStyle(.red)
            case .ejecting:
                Text("Ejecting…")
                    .foregroundStyle(.secondary)
            case .idle:
                Text("Ejecting removes \(drive.volumes.count) volumes")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var ejectButton: some View {
        if drive.isStartupDisk {
            EmptyView()
        } else if store.ejectState(of: drive) == .ejecting {
            ProgressView()
                .controlSize(.small)
        } else {
            Button {
                Task { await store.eject(drive) }
            } label: {
                Image(systemName: "eject.fill")
            }
            .buttonStyle(.borderless)
            .help("Eject \(drive.name)")
        }
    }
}

private struct VolumeRow: View {
    @ObservedObject var store: VolumeStore
    let volume: ExternalVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(volume.name)
                .lineLimit(1)
            let names = store.holderLabels(of: volume)
            if !names.isEmpty {
                Text("In use by \(ListFormatter.localizedString(byJoining: names))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
