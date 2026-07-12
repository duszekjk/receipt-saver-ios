import SwiftUI

struct UndoButtonView: View {
    let onUndone: () -> Void

    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var status: UndoStatus?
    @State private var isWorking = false

    var body: some View {
        Group {
            if let status = status, status.can_undo {
                Button {
                    Task { await undo(label: status.label) }
                } label: {
                    if isWorking {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.uturn.backward")
                    }
                }
                .disabled(isWorking)
                .accessibilityLabel("Cofnij")
                .accessibilityHint(status.label)
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        do {
            status = try await APIClient.shared.undoStatus()
        } catch {
            status = nil
        }
    }

    private func undo(label: String) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            status = try await APIClient.shared.undoLastOperation()
            onUndone()
            toastCenter.show("Cofnięto: \(label)", style: .success)
        } catch {
            toastCenter.show(error.localizedDescription, style: .error, duration: 4)
        }
    }
}
