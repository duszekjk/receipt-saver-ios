import Combine
import SwiftUI

enum AppToastStyle {
    case success
    case error
    case info

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct AppToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: AppToastStyle
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published private(set) var toast: AppToast?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, style: AppToastStyle = .info, duration: TimeInterval = 2.5) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            toast = AppToast(message: message, style: style)
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(duration, 0.5) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            toast = nil
        }
    }
}

private struct AppToastOverlay: ViewModifier {
    @ObservedObject var center: ToastCenter

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let toast = center.toast {
                HStack(spacing: 9) {
                    Image(systemName: toast.style.systemImage)
                    Text(toast.message)
                        .font(.subheadline)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(radius: 8, y: 3)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { center.dismiss() }
                .zIndex(1000)
            }
        }
    }
}

extension View {
    func appToastOverlay(_ center: ToastCenter = .shared) -> some View {
        modifier(AppToastOverlay(center: center))
    }
}
