import SwiftUI

struct GuestMainView: View {
    @ObservedObject var accessStore: AppAccessStore

    private let categories = [
        ("Żywność", "327,40 zł"),
        ("Transport", "184,20 zł"),
        ("Mieszkanie", "1 240,00 zł"),
        ("Kultura i media", "79,98 zł")
    ]

    var body: some View {
        TabView {
            NavigationView {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tryb gościa")
                                .font(.headline)
                            Text("Dane są przykładowe i pozostają wyłącznie w aplikacji. Tryb gościa nie łączy się z prywatnym serwerem ani kontami Django.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 6)
                    }

                    Section("Podsumowanie miesiąca") {
                        HStack {
                            Text("Wydatki")
                            Spacer()
                            Text("1 831,58 zł").bold()
                        }
                        HStack {
                            Text("Oszczędności")
                            Spacer()
                            Text("83,20 zł")
                        }
                    }

                    Section("Kategorie") {
                        ForEach(categories, id: \.0) { item in
                            HStack {
                                Text(item.0)
                                Spacer()
                                Text(item.1)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Receipt Saver")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Zaloguj się") {
                            accessStore.leaveGuestMode()
                        }
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar.fill")
            }

            NavigationView {
                List {
                    Section("Przykładowe paragony") {
                        guestRow(title: "Lidl", subtitle: "8 pozycji • 126,47 zł")
                        guestRow(title: "Orlen", subtitle: "2 pozycje • 238,31 zł")
                        guestRow(title: "Empik", subtitle: "Książka • 49,99 zł")
                    }
                    Section {
                        Text("Skanowanie i wysyłanie zdjęć jest dostępne po zalogowaniu na konto utworzone przez administratora.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Paragony")
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Paragony", systemImage: "doc.text.fill")
            }

            NavigationView {
                List {
                    Section("Przykładowe transakcje") {
                        guestRow(title: "Autostrada Wielkopolska", subtitle: "Transport › opłaty drogowe • 34,00 zł")
                        guestRow(title: "Apple", subtitle: "Kultura i media › filmy • 29,99 zł")
                        guestRow(title: "PZU", subtitle: "Finanse › ubezpieczenie • 126,00 zł")
                    }
                    Section {
                        Text("Import wyciągów bankowych jest wyłączony w trybie gościa.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Transakcje")
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Transakcje", systemImage: "creditcard.fill")
            }
        }
    }

    private func guestRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 3)
    }
}
