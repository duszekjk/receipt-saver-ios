import SwiftUI

struct MainTabView: View {
    @State private var refreshID = UUID()

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                    BankTransactionsView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label("Transakcje", systemImage: "creditcard.fill")
                }

                NavigationView {
                    MatchReviewView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label("Dopasowania", systemImage: "checkmark.seal.fill")
                }
            }
            .id(refreshID)

            UndoButtonView {
                refreshID = UUID()
            }
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
    }
}