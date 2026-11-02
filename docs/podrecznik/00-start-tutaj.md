# Start tutaj

Podręcznik właściciela software house'u, w którym pracują agenci AI. Opisuje wyłącznie to, co
działa dziś, czyli **etap A (pilot)**. Rzeczy zapowiedziane, ale jeszcze niedostępne, mają dopisek
„etap B (jeszcze niedostępne)”.

## Czym jest system

Zlecasz pracę zwykłym językiem, w czacie. Resztę robią agenci na serwerze (iMac w biurze):

- **orkiestrator** (Claude Code) prowadzi projekt, rozmawia z Tobą i rozdziela pracę;
- **workerzy** (Claude Code) piszą kod i testy, każdy w osobnej kopii repozytorium;
- **reviewer** (Codex) sprawdza każdą zmianę, zanim trafi do głównej gałęzi;
- **shctl** to program, który wykonuje mechanikę: zakłada zadania, kopie robocze, panele i wpisy.

Ty akceptujesz pracę w kilku punktach kontrolnych i odpowiadasz na pytania, których agenci nie mogą
rozstrzygnąć sami. Wszystko, co powstaje, ląduje w repozytoriach na GitHubie, a Ty czytasz to w
Obsidianie.

## Mapa podręcznika

| Plik | Kiedy czytać |
|---|---|
| [[01-jak-to-dziala]] | Na początek: jak płynie zlecenie, tryby S i M, Twoja rola, granice bezpieczeństwa |
| [[02-codzienna-praca]] | Codziennie: czat z orkiestratorem, polecenia, powiadomienia, Obsidian |
| [[03-skille]] | Gdy chcesz wiedzieć, który agent co robi i kiedy czeka na Ciebie |
| [[04-shctl]] | Gdy chcesz sam coś sprawdzić w terminalu |
| [[05-serwer-i-skrypty]] | Gdy chodzi o serwer: autostart, strażnik limitów, synchronizacja, kopie |
| [[06-przyklad-od-zera]] | Pełny przykład: strona firmowa od pomysłu do odbioru |
| [[07-gdy-cos-nie-dziala]] | Gdy przyszło niepokojące powiadomienie albo coś stoi |
| [[08-slownik]] | Gdy nie znasz jakiegoś pojęcia |

Szczegóły techniczne są w dokumentach systemu: [[proces-v1]] (proces), [[shctl]] (komendy),
[[serwer]] (serwer).

## 5 rzeczy do zapamiętania

1. **Rozmawiasz tylko z orkiestratorem.** Sesja `sh-orkiestrator` w aplikacji Claude. Piszesz
   zwykłym językiem: „status?”, „wznów”, „STOP”, „akceptuję”.
2. **W Obsidianie tylko czytasz.** Folder `SH/` w vaulcie to kopie repozytoriów. Zmiana zapisana
   tam zatrzymuje synchronizację. Poprawki zlecasz orkiestratorowi.
3. **Czekamy na Ciebie w trzech miejscach.** W trybie M: akceptacja specyfikacji, akceptacja
   architektury z planem i odbiór. W trybie S: tylko odbiór. Plus eskalacje, gdy przyjdą.
4. **Po limicie albo restarcie piszesz „wznów”.** W etapie A nikt nie wznawia pracy za Ciebie.
   Powiadomienie „Limit … odnowiony” znaczy: możesz napisać „wznów”.
5. **Produkcja należy tylko do Ciebie.** Na serwerze nie ma żadnych kluczy produkcyjnych, a w
   etapie A nie ma wdrożeń produkcyjnych. W razie kłopotów piszesz „STOP”.
