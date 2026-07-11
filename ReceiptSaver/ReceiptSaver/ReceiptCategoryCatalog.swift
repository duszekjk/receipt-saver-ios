import Foundation

struct ReceiptCategoryOption: Identifiable, Hashable {
    let category: String
    let subcategory: String
    let synonyms: [String]

    var id: String { "\(category)|\(subcategory)" }
}

enum ReceiptCategoryCatalog {
    static let categories: [String: [String]] = [
        "Żywność": ["owoce", "warzywa", "pieczywo", "nabiał", "jaja", "sery", "jogurty", "masło", "mięso", "wędliny", "ryby", "mrożonki", "produkty sypkie", "makarony i kasze", "dodatki do pieczenia", "przyprawy", "słodycze", "miód", "dżemy i kremy", "napoje", "woda", "soki", "kawa", "herbata", "gotowe dania", "konserwy", "sosy i dodatki"],
        "Zdrowie": ["lekarz", "dentysta", "okulista", "rehabilitacja", "apteka", "leki", "suplementy", "sprzęt medyczny", "badania"],
        "Dom": ["chemia domowa", "środki czystości", "papier toaletowy", "ręczniki papierowe", "pranie", "kuchnia", "wyposażenie domu", "meble", "remont", "narzędzia", "ogród", "kwiaty", "dekoracje"],
        "Higiena": ["kosmetyki", "higiena osobista", "fryzjer"],
        "Transport": ["paliwo", "parking", "opłaty drogowe", "komunikacja miejska", "kolej", "taxi", "serwis samochodu", "części samochodowe", "myjnia"],
        "Mieszkanie": ["prąd", "gaz", "woda", "internet", "telefon", "czynsz", "ogrzewanie", "śmieci"],
        "Restauracje": ["restauracja", "fast food", "kawiarnia", "cukiernia"],
        "Ubrania": ["odzież", "obuwie", "bielizna", "naprawa ubrań"],
        "Akcesoria osobiste": ["parasole", "portfele", "okulary", "zegarki", "biżuteria", "torby i plecaki"],
        "Zwierzęta": ["karma", "weterynarz", "leki", "akcesoria", "pielęgnacja"],
        "Sport i rekreacja": ["sprzęt sportowy", "siłownia", "basen", "zajęcia sportowe", "rekreacja"],
        "Kultura i media": ["książki", "filmy", "muzyka", "gry", "prasa"],
        "Hobby": ["ogród", "rękodzieło", "kolekcjonerstwo", "elektronika", "modelarstwo"],
        "Rodzina": ["dzieci", "wnuki", "opieka nad dziećmi", "prezenty", "uroczystości"],
        "Wydarzenia": ["pielgrzymki", "rekolekcje", "spotkania wspólnoty", "konferencje", "wyjazdy", "wolontariat"],
        "Finanse": ["bank", "ubezpieczenie", "podatki", "opłata finansowa", "kredyt i pożyczka"],
        "Darowizny": ["kościół", "wspólnota", "fundacja", "rodzina"],
        "Edukacja": ["studia", "kursy", "materiały edukacyjne", "szkolenia"],
        "Subskrypcje": ["streaming wideo", "streaming muzyki", "chmura", "oprogramowanie", "aplikacje", "prasa cyfrowa", "AI"],
        "Hazard": ["lotto", "zakłady sportowe", "kasyno", "poker", "automaty", "gry online"],
        "Alkohol": ["piwo", "wino", "mocny alkohol", "likier", "cydr", "drinki"],
        "Opakowania i torby": ["reklamówki", "torby papierowe", "torby wielorazowe", "opakowania", "pojemniki"],
        "Opłaty techniczne": ["kaucja", "depozyt", "opłata serwisowa", "opłata manipulacyjna", "opłata dostawy"],
        "Promocje i korekty": ["rabat", "kupon", "zwrot", "korekta ceny", "zaokrąglenie"],
        "Usługi": ["usługi sklepowe", "naprawy", "czyszczenie", "drukowanie", "dorabianie kluczy", "usługi profesjonalne"],
        "Biuro i papiernicze": ["papier", "artykuły piśmiennicze", "druk", "koperty", "organizacja dokumentów"],
        "Elektronika i akcesoria": ["baterie", "kable", "ładowarki", "akcesoria telefoniczne", "akcesoria komputerowe", "sprzęt elektroniczny"],
        "Prezenty": ["upominki", "kartki okolicznościowe", "pakowanie prezentów"],
        "Podróże": ["noclegi", "bilety", "bagaż", "ubezpieczenie podróżne", "wycieczki"],
        "Administracyjne": ["urząd", "poczta", "mandaty", "dokumenty", "opłaty urzędowe"],
        "Nieczytelne pozycje": ["pozycja nieczytelna", "skrót nierozpoznany", "produkt niejednoznaczny"]
    ]

    private static let synonyms: [String: [String]] = [
        key("Transport", "opłaty drogowe"): ["autostrada", "autostrady", "winieta", "winiety", "e-toll", "etoll", "bramka", "bramki autostradowe", "opłata za przejazd", "droga płatna", "płatny tunel", "płatny most", "amberone", "autopay"],
        key("Transport", "parking"): ["postój", "parkomat", "mobilet", "strefa parkowania"],
        key("Transport", "paliwo"): ["benzyna", "diesel", "olej napędowy", "tankowanie", "stacja paliw"],
        key("Finanse", "ubezpieczenie"): ["polisa", "oc", "ac", "nnw", "ubezpieczenia", "składka ubezpieczeniowa"],
        key("Kultura i media", "książki"): ["książka", "ebook", "e-book", "kindle", "publio", "legimi", "audiobook"],
        key("Kultura i media", "filmy"): ["film", "movie", "dvd", "blu-ray", "bluray", "vod", "apple tv", "wypożyczenie filmu"],
        key("Kultura i media", "muzyka"): ["album", "płyta", "cd", "winyl", "vinyl", "itunes", "utwór"],
        key("Kultura i media", "gry"): ["gra", "steam", "playstation", "xbox", "nintendo", "dlc"],
        key("Subskrypcje", "streaming wideo"): ["netflix", "max", "disney+", "prime video", "abonament filmowy"],
        key("Subskrypcje", "streaming muzyki"): ["spotify", "apple music", "tidal", "youtube music"],
        key("Subskrypcje", "chmura"): ["icloud", "icloud+", "google one", "dropbox", "onedrive", "dysk w chmurze"],
        key("Subskrypcje", "AI"): ["chatgpt", "openai", "claude", "gemini", "sztuczna inteligencja"],
        key("Dom", "wyposażenie domu"): ["wyposażenie", "artykuły domowe", "gospodarstwo domowe"],
        key("Sport i rekreacja", "siłownia"): ["fitness", "gym", "karnet sportowy"],
        key("Administracyjne", "opłaty urzędowe"): ["opłata skarbowa", "urząd", "wniosek", "administracja"]
    ]

    static var categoryNames: [String] {
        categories.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func subcategories(for category: String) -> [String] {
        categories[category] ?? []
    }

    static var allOptions: [ReceiptCategoryOption] {
        categoryNames.flatMap { category in
            subcategories(for: category).map { subcategory in
                ReceiptCategoryOption(category: category, subcategory: subcategory, synonyms: synonyms[key(category, subcategory)] ?? [])
            }
        }
    }

    static func search(_ query: String) -> [ReceiptCategoryOption] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return allOptions }
        return allOptions.filter { option in
            ([option.category, option.subcategory] + option.synonyms).contains { normalize($0).contains(normalizedQuery) }
        }
    }

    private static func key(_ category: String, _ subcategory: String) -> String {
        "\(category)|\(subcategory)"
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }
}
