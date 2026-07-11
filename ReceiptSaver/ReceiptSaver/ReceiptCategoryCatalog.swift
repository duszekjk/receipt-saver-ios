import Foundation

enum ReceiptCategoryCatalog {
    static let categories: [String: [String]] = [
        "Żywność": ["owoce", "warzywa", "pieczywo", "nabiał", "jaja", "sery", "jogurty", "masło", "mięso", "wędliny", "ryby", "mrożonki", "produkty sypkie", "makarony i kasze", "dodatki do pieczenia", "przyprawy", "słodycze", "miód", "dżemy i kremy", "napoje", "woda", "soki", "kawa", "herbata", "gotowe dania", "konserwy", "sosy i dodatki"],
        "Zdrowie": ["lekarz", "dentysta", "okulista", "rehabilitacja", "apteka", "leki", "suplementy", "sprzęt medyczny", "badania"],
        "Dom": ["chemia domowa", "środki czystości", "papier toaletowy", "ręczniki papierowe", "pranie", "kuchnia", "remont", "narzędzia", "ogród", "kwiaty", "dekoracje"],
        "Higiena": ["kosmetyki", "higiena osobista", "fryzjer"],
        "Transport": ["paliwo", "parking", "komunikacja miejska", "taxi", "serwis samochodu", "opłaty drogowe", "autostrady", "winiety"],
        "Mieszkanie": ["prąd", "gaz", "woda", "internet", "telefon", "czynsz", "ogrzewanie", "śmieci"],
        "Restauracje": ["restauracja", "fast food", "kawiarnia", "cukiernia"],
        "Ubrania": ["odzież", "obuwie", "bielizna", "naprawa ubrań"],
        "Akcesoria osobiste": ["parasole", "portfele", "okulary", "zegarki", "biżuteria", "torby i plecaki"],
        "Zwierzęta": ["karma", "weterynarz", "leki", "akcesoria"],
        "Hobby": ["książki", "ogród", "rękodzieło", "sport", "elektronika", "prasa"],
        "Rodzina": ["dzieci", "wnuki", "prezenty", "uroczystości"],
        "Wydarzenia": ["pielgrzymki", "rekolekcje", "spotkania wspólnoty", "konferencje", "wyjazdy", "wolontariat"],
        "Finanse": ["bank", "ubezpieczenie", "podatki", "opłata"],
        "Darowizny": ["kościół", "wspólnota", "fundacja", "rodzina"],
        "Edukacja": ["studia", "kursy", "książki", "szkolenia"],
        "Subskrypcje": ["internetowe", "streaming", "oprogramowanie", "aplikacje"],
        "Hazard": ["lotto", "zakłady sportowe", "kasyno", "poker", "automaty", "gry online"],
        "Alkohol": ["piwo", "wino", "mocny alkohol", "likier", "cydr", "drinki"],
        "Opakowania i torby": ["reklamówki", "torby papierowe", "torby wielorazowe", "opakowania", "pojemniki"],
        "Opłaty techniczne": ["kaucja", "depozyt", "opłata serwisowa", "opłata manipulacyjna", "opłata dostawy"],
        "Promocje i korekty": ["rabat", "kupon", "zwrot", "korekta ceny", "zaokrąglenie"],
        "Usługi": ["usługi sklepowe", "naprawy", "czyszczenie", "drukowanie", "dorabianie kluczy"],
        "Biuro i papiernicze": ["papier", "artykuły piśmiennicze", "druk", "koperty", "organizacja dokumentów"],
        "Elektronika i akcesoria": ["baterie", "kable", "ładowarki", "akcesoria telefoniczne", "akcesoria komputerowe"],
        "Prezenty": ["upominki", "kartki okolicznościowe", "pakowanie prezentów"],
        "Podróże": ["noclegi", "bilety", "bagaż", "ubezpieczenie podróżne"],
        "Administracyjne": ["urząd", "poczta", "mandaty", "dokumenty"],
        "Nieczytelne pozycje": ["pozycja nieczytelna", "skrót nierozpoznany", "produkt niejednoznaczny"]
    ]

    static var categoryNames: [String] {
        categories.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func subcategories(for category: String) -> [String] {
        categories[category] ?? []
    }
}
