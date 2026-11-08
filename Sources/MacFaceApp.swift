import AppKit
import SwiftUI

@MainActor
final class FaceGate: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isScanning = false
    @Published private(set) var message: String?
    private var generation = UUID()

    func scan() {
        guard !isScanning, !isUnlocked else { return }
        isScanning = true
        message = nil
        let attempt = generation
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try MugshotClient().verifyFace() }
            }.value
            isScanning = false
            // The recognition HUD may briefly change focus. A real session lock,
            // sleep, or closing the window still invalidates any pending result.
            guard attempt == generation else { return }
            switch result {
            case .success(true):
                isUnlocked = true
            case .success(false):
                message = "얼굴을 확인하지 못했습니다. 카메라를 정면으로 보고 다시 시도하세요."
            case .failure(MugshotClient.Failure.untrusted):
                message = "Mugshot의 서명을 확인하지 못했습니다. 공식 Mugshot을 다시 실행해 주세요."
            case .failure:
                message = "Mugshot에 연결하지 못했습니다. 앱이 실행 중인지 확인하고 다시 시도하세요."
            }
        }
    }

    func lock() {
        generation = UUID()
        isUnlocked = false
        message = nil
    }
}

@main
struct MacFaceApp: App {
    var body: some Scene {
        Window("Mac Face", id: "main") {
            FaceGateView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct FaceGateView: View {
    @StateObject private var gate = FaceGate()
    private let screenLock = Notification.Name("com.apple.screenIsLocked")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Mac Face", systemImage: "faceid")
                    .font(.headline)
                Spacer()
                Label(gate.isUnlocked ? "열림" : "잠김", systemImage: gate.isUnlocked ? "lock.open.fill" : "lock.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 24).padding(.vertical, 16)

            Divider()

            VStack(spacing: 14) {
                Image(systemName: gate.isUnlocked ? "checkmark.shield" : "faceid")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(gate.isUnlocked ? Color.green : Color.accentColor)
                    .frame(width: 76, height: 76)
                    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityHidden(true)

                Text(gate.isUnlocked ? "보호 화면이 열렸습니다" : "얼굴로 잠금 해제")
                    .font(.system(size: 25, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)

                if gate.isUnlocked {
                    Text("얼굴 인증이 성공한 뒤에만 보이는 앱 내부 화면입니다.")
                        .foregroundStyle(.secondary)
                    Button("다시 잠그기") { gate.lock() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Text(gate.isScanning ? "카메라를 정면으로 바라보세요." : "Mugshot에 등록한 얼굴로 이 화면을 열 수 있습니다.")
                        .foregroundStyle(.secondary)
                    Button(action: { gate.scan() }) {
                        HStack(spacing: 8) {
                            if gate.isScanning { ProgressView().controlSize(.small) }
                            Text(gate.isScanning ? "확인 중…" : "얼굴 인증")
                        }
                        .frame(minWidth: 110)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(gate.isScanning)
                }

                if let message = gate.message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Mugshot 열기") {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.lorenzo.Mugshot") {
                            NSWorkspace.shared.openApplication(at: url, configuration: .init())
                        }
                    }
                    .buttonStyle(.link)
                }
            }
            .controlSize(.large)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 263)
            .padding(22)

            Divider()
            Label("얼굴 확인은 이 Mac에서 처리합니다", systemImage: "laptopcomputer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24).padding(.vertical, 13)
        }
        .frame(width: 468)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in gate.lock() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in gate.lock() }
        .onReceive(DistributedNotificationCenter.default().publisher(for: screenLock)) { _ in gate.lock() }
        .onDisappear { gate.lock() }
    }

}
