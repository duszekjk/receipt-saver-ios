# Receipt Saver iOS

Minimalna aplikacja SwiftUI dla iOS 15.

## Funkcje MVP

- zrobienie zdjęcia paragonu lub wybór z biblioteki,
- lekkie preprocessing/zmniejszenie zdjęcia przed wysyłką,
- upload do Django endpointu `/api/receipts/scan/`,
- lista podsumowań: miesiąc, kwartał, półrocze, rok,
- lista paragonów,
- kolejka ręcznej weryfikacji niepewnych dopasowań bank ↔ paragon.

## Uruchomienie

1. Utwórz w Xcode nowy projekt iOS App o nazwie `ReceiptSaver`.
2. Skopiuj folder `ReceiptSaver/` z tego repo do projektu.
3. W `APIClient.swift` ustaw `baseURL` na swój serwer Django.
4. Podmień tymczasowy `bearerToken` na właściwe logowanie.

Docelowo można dodać Sign in with Apple albo tokeny DRF/JWT.
