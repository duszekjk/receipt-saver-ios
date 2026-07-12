import SwiftUI

struct UndoButtonView: View {
    let onUndone: () -> Void

    @State private var status: UndoStatus?
    @State private var isWorking = false
    @State private var showInfo = false
    @State private var toastMessage = ""
    @State private var toastDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let status = status, status.can_undo {
                undoControl(status: status)
                    .popover(isPresented: $showInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cofnij")
                                .font(.headline)
                            Text(status.label)
                                .font(.subheadline)
                            Text("Dostępnych cofnięć: \(status.remaining)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: 280, alignment: .leading)
                    }
            }

            if !toastMessage.isEmpty {
                Text(toastMessage)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 3)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .task { await reload() }
        .onDisappear {
            toastDismissTask?.cancel()
        }
    }

    private func undoControl(status: UndoStatus) -> some View {
        Group {
            if isWorking {
                ProgressView()
                    .frame(width: 18, height: 18)
                    .padding(9)
            } else {
                Image(systemName: "arrow.uturn.backward")
                    .font(.body.weight(.semibold))
                    .frame(width: 18, height: 18)
                    .padding(9)
                    .contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.55)
                            .exclusively(before: TapGesture())
                            .onEnded { value in
                                switch value {
                                case .first:
                                    showInfo = true
                                case .second:
                                    Task { await undo(label: status.label) }
                                }
                            }
                    )
            }
        }
        .background(.thinMaterial)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.18), lineWidth: 0.5))
        .accessibilityLabel("Cofnij")
        .accessibilityHint(status.label)
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
            showToast("Cofnięto: \(label)")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func showToast(_ message: String) {
        toastDismissTask?.cancel()
        toastMessage = message
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                toastMessage = ""
            }
        }
    }
}
