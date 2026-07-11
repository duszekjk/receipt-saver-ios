import SwiftUI

struct UndoButtonView: View {
    let onUndone: () -> Void

    @State private var status: UndoStatus?
    @State private var isWorking = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let status = status, status.can_undo {
                Button {
                    Task { await undo() }
                } label: {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isWorking ? "Cofanie…" : "Cofnij")
                                .font(.headline)
                            Text(status.label)
                                .font(.caption)
                                .lineLimit(1)
                            Text("Pozostało: \(status.remaining)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
                .accessibilityLabel("Cofnij: \(status.label)")
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        do {
            status = try await APIClient.shared.undoStatus()
            errorMessage = ""
        } catch {
            status = nil
        }
    }

    private func undo() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = ""
        defer { isWorking = false }
        do {
            status = try await APIClient.shared.undoLastOperation()
            onUndone()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}