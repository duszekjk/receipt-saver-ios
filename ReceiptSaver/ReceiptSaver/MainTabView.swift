import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            NavigationView {
                ReceiptListView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Paragony", systemImage: "doc.text.fill")
            }

            NavigationView {
                MatchReviewView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Dopasowania", systemImage: "checkmark.seal.fill")
            }
        }
    }
}
