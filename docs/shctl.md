# shctl

<!-- Plik generowany przez scripts/docs/shctl-md.sh z `shctl --help` i `shctl KOMENDA --help`.
     Nie edytuj: zmień scripts/shctl/pomoc/*.txt i uruchom skrypt. CI sprawdza zgodność. -->

CLI z mechaniką procesu (`docs/proces.md`): agent decyduje i pisze treść, a `shctl` wykonuje
operacje na plikach, GitHubie i panelach herdr. Źródło: `scripts/shctl/` (`cmd/` komendy,
`lib/`, `pomoc/` teksty pomocy, `tests/` bats). Symlink `/Users/Shared/sh/bin/shctl` zakłada
`scripts/server/install.sh`. Zależności: bash 3.2+, gh, jq, yq (mikefarah), git, herdr.

Komendy: [new-project](#new-project), [adopt](#adopt), [repo](#repo), [stage](#stage), [decision](#decision), [escalate](#escalate), [status](#status), [stop-all](#stop-all), [skrzynka](#skrzynka), [obsidian](#obsidian), [doctor](#doctor), [task](#task), [pr](#pr), [review](#review), [reset-dryrun](#reset-dryrun), [template](#template), [sprzataj](#sprzataj), [metryki](#metryki).

## shctl --help

```text
Użycie: shctl KOMENDA [argumenty] [--dry-run] [--json] [--projekt NAZWA]

  new-project NAZWA --opis "krótki opis repo" [--zlecenie "..."] [--tryb S|M] [--prywatny]
  adopt OWNER/REPO --nazwa NAZWA [--tryb M|S] [--limit-analizy MIN]
  adopt adaptacja|bramka|upublicznij --projekt NAZWA
  repo opis [--opis "..."] [--topics "a,b"] [--website URL]
  stage start|review|done|escalate ETAP [--notatka "..."]
  stage iter ETAP
  decision add --co "..." --dlaczego "..." --cofniecie "..." [--rola ROLA]
  escalate --dotyczy "#NR|ETAP" --powod "..." --sytuacja "..." --sprawdzono "..." --potrzebne "..." [--opcje "A;B"] [--priorytet high] [--akceptacja] [--typ blokada|pytanie]
  escalate close E-NNN --odpowiedz "..."
  status show
  stop-all
  skrzynka przyjmij NAZWA
  obsidian link|unlink NAZWA
  doctor [--test-notify]
  task create --plik zadania.yaml
  task ready [--czekaj] [--timeout SEKUNDY]
  task dispatch NR
  task iter NR [--odbior "kryterium"]
  task close NR [--odbior] [--anuluj [--powod "..."]]   (task cancel NR: alias do następnej wersji)
  task resume-check NR [--testy "..."] [--bez-testow]
  task wait NR [--timeout SEKUNDY]
  task deps NR [--usun #X] [--dodaj #X]
  task polecenie NR "tekst"
  pr check PR [--czekaj] [--timeout SEKUNDY]
  review run PR [--timeout SEKUNDY]
  reset-dryrun
  template update [--baseline] [--force]
  sprzataj
  metryki serwer [--probki N] [--co SEKUNDY]
  metryki skille

Opcje wspólne (w dowolnym miejscu po nazwie komendy):
  --dry-run        pokazuje, co by się stało; nie zapisuje, nie zmienia GitHuba, nie powiadamia
  --json           na stdout dokładnie jeden dokument JSON, także przy błędzie
  --projekt NAZWA  projekt z /Users/Shared/sh/projekty/NAZWA; bez opcji z bieżącego katalogu
  --help           opis komendy: shctl KOMENDA --help

Kody wyjścia:
  0 sukces, także bez zmian; 1 błąd wykonania (gh, git, sieć, powiadomienie, kontrola doctor);
  2 błędne użycie; 3 brak projektu, pliku lub narzędzia; 4 odmowa według reguł procesu.

JSON: {"ok":true,"komenda":"…","dry_run":false,"wynik":{…}} albo {"ok":false,"kod":N,"blad":"…"}.
Każda komenda jest idempotentna: powtórka niczego nie dubluje, a przerwaną operację dokańcza.
Każde wywołanie dopisuje linię do /Users/Shared/sh/logs/shctl.log. Commit na main projektu robi
orkiestrator; shctl commituje sam tylko w new-project, template update, reset-dryrun, skrzynka i adopt
(szkielet analizy i adaptacja, na swoich gałęziach).

Zmienne środowiska (testy i inny układ; w nawiasie domyślnie):
  SH_DIR (/Users/Shared/sh), SH_GH_OWNER (Sebastian-Temich), SH_TEMPLATE (sh-template-projekt),
  SH_NOTIFY_CMD ($SH_DIR/bin/notify.sh), SH_CONFIG (~/.config/sh/config), SH_OBSIDIAN_DIR (z
  SH_CONFIG), SH_SKRZYNKA_DIR (Skrzynka obok SH_OBSIDIAN_DIR), SH_SYSTEM_DIR ($SH_DIR/sh-system),
  SH_WARSTWY_SKILLI, SH_SKILLE_PLUGINU (sh-system/plugin), SH_CLAUDE_JSON (~/.claude.json),
  CODEX_HOME (~/.codex), SHCTL_REVIEW_TIMEOUT (3600), SHCTL_TEST_TIMEOUT (1800),
  SHCTL_READY_PAUZA (30), SHCTL_FNM_LIMIT (300), SHCTL_DRYRUN_NAZWA (sh-dryrun).

Dokumentacja: sh-system/docs/shctl.md (generowana z --help: scripts/docs/shctl-md.sh)
```

## new-project

```text
Użycie: shctl new-project NAZWA --opis "krótki opis repo" [--zlecenie "..."] [--tryb S|M] [--prywatny]

Zakłada projekt SH: repo SH_GH_OWNER/NAZWA (domyślnie publiczne, bez „generated from”), pliki
szablonu sh-template-projekt jako pierwszy commit w /Users/Shared/sh/projekty/NAZWA, opis i temat
sh-projekt (gh repo edit), etykiety, frontmatter docs/konfiguracja.md (tryb_procesu,
etap_wdrozenia, blok_portow), blok portów w porty.md, zlecenie w docs/00-intake/zrodlo.md,
widok docs/Projekt.md, check-dod.sh, gitleaks (sekret: kod 4, bez pushu), push na main i ruleset
sh-ochrona-galezi (bez usuwania i force push na main i production). Na końcu klon docs/ w vaulcie
Obsidiana i skrzynka na materiały (jak obsidian link).

  --opis       wymagany: opis repo na GitHubie, do 350 znaków
  --zlecenie   treść zlecenia do docs/00-intake/zrodlo.md
  --tryb       M (domyślnie) albo S (z ostrzeżeniem: nowy projekt zaczyna od M); L: kod 2
  --prywatny   tylko na wyraźne polecenie właściciela; zmienna repo SH_RUNS_ON kieruje CI na
               runner serwera (docs/serwer.md, „Repo prywatne”)

W trybie S wszystkie etapy dostają status pominiety. Odmowa (kod 4): repo istnieje i nie jest
projektem SH, katalog jest klonem innego repo, sekret w plikach, --tryb inny niż w projekcie.
Wynik JSON: repo, katalog, tryb, kroki, porty, obsidian (katalog, skrzynka).
```

## adopt

```text
Użycie: shctl adopt OWNER/REPO --nazwa NAZWA [--tryb M|S] [--limit-analizy MIN]
        shctl adopt adaptacja --projekt NAZWA
        shctl adopt bramka --projekt NAZWA
        shctl adopt upublicznij --projekt NAZWA

Przejęcie istniejącego projektu (docs/proces.md, „Projekty przejęte”). Repo prywatne zostaje
prywatne: adopt nigdy sam nie zmienia widoczności.

Start (OWNER/REPO): pełny klon w /Users/Shared/sh/projekty/NAZWA bez plików env i bez dostępu do
produkcji, worktree /Users/Shared/sh/wt/NAZWA/stage-00-analiza na gałęzi stage/00-analiza z commitem
szkieletu etapu: docs/konfiguracja.md (pochodzenie: adopt, adopt.repo, widocznosc, analiza_od,
analiza_do, limit_analizy_min, lovable, supabase), docs/decyzje.md, docs/00-analiza/ (DoD.md,
raport.md, wykryj.json z scripts/adopt/wykryj.sh). Blok portów w porty.md, klon docs/ w Obsidianie
i skrzynka. Bez pushu: PR raportu otwiera sh-intake w trybie adopt. Limit analizy: --limit-analizy,
inaczej adopt.limit_analizy_min z /Users/Shared/sh/konfiguracja.md, inaczej 120 minut.

  --nazwa            wymagana: nazwa projektu (litery, cyfry, - i _)
  --tryb             M (domyślnie) albo S: tryb zleceń po adaptacji
  --limit-analizy    limit czasu analizy w minutach

adaptacja: po merge'u analizy i checkpoincie (wszystkie pola docs/00-analiza/DoD.md zaznaczone i
wiersz wlasciciel z „analiz” w decyzje.md). Worktree wt/NAZWA/adaptacja na gałęzi adopt/adaptacja,
brakujące pliki szablonu sh-template-projekt (AGENTS.md, CLAUDE.md, docs/ v2, scripts/,
.claude/roles/, szablony issue i PR) bez kodu aplikacji i bez CI szablonu; obok istniejącego CI
workflow .github/workflows/sh.yml (check-dod, gitleaks). Plik projektu różny od szablonu zostaje
(lista „pominięte” w PR). Projekt z Lovable: sekcja „Lovable” w AGENTS.md. Etykiety, w repo
prywatnym zmienna SH_RUNS_ON, gitleaks commitu adaptacji, check-dod, push i PR.

bramka: przed upublicznieniem repo. gitleaks na całej historii (sekret = zalecenie unieważnienia u
dostawcy, bez przepisywania historii), tabele public bez RLS w migracjach, przegląd RLS w raporcie
analizy, dane osobowe w seedach i fixture'ach, pliki env i klucz service_role w repo. Blokada: kod 4.

upublicznij: tylko z wierszem wlasciciel z „upublicz” w decyzje.md i po bramce bez blokad; gh repo
edit --visibility public i adopt.widocznosc w konfiguracja.md (commit robi orkiestrator).

Odmowa (kod 4): repo zarchiwizowane albo puste, domyślna gałąź inna niż main, katalog jest klonem
innego repo, repo ma już docs/konfiguracja.md spoza adopt, brak checkpointu, blokada bramki.
Brak repo albo dostępu: kod 3.
Wynik JSON (start): repo, katalog, worktree, galaz, tryb, widocznosc, limit_analizy_min, porty,
obsidian, lovable, supabase, alarmy, kroki.
```

## repo

```text
Użycie: shctl repo opis [--opis "..."] [--topics "a,b"] [--website URL]

Opis (do 350 znaków), tematy (zawsze z sh-projekt) i strona repo projektu przez gh repo edit.
Orkiestrator wywołuje ją na checkpointach specyfikacji, planu i odbioru: najpierw --dry-run, które
wypisuje dokładną komendę gh repo edit do pokazania właścicielowi, potem po jego zgodzie bez
--dry-run. gh repo edit poza shctl jest w procesie zabronione.
Wynik JSON: repo, komenda, opis, tematy, strona.
```

## stage

```text
Użycie: shctl stage start|review|done|escalate ETAP [--notatka "..."]
        shctl stage iter ETAP

Status etapu w docs/ETAP/DoD.md na main. ETAP to nazwa folderu: 00-intake, 04-plan, 06-zadania,
08-qa, wydanie (wersja_procesu 2); projekty bez pola wersja_procesu mają 04-architektura i
05-plan zamiast 04-plan. Każda zmiana odświeża docs/Projekt.md i dopisuje wpis do „Dziennika
etapów” w docs/historia.md.

  start      z todo, review, escalated, in-progress  -> in-progress
  review     z in-progress, review                   -> review
  done       z review, done                          -> done, tylko po zielonym check-dod.sh
  escalate   z todo, in-progress, review, escalated  -> escalated (plik eskalacji: shctl escalate)

Etap czekający na coś zewnętrznego: stage start ETAP --notatka "czeka na ...". Pominięcia nie ma
w shctl: orkiestrator zapisuje decision add i ustawia w DoD.md status: pominiety z polem decyzja.

stage iter ETAP: po FAIL review etapu podbija iteracja w DoD.md i ustawia in-progress (na main;
gałąź stage/ETAP frontmattera nie zmienia). Wymaga otwartego PR z gałęzi stage/ETAP i FAIL dla jego
bieżącego commita. Etapy 00-intake, 04-plan, 06-zadania: najwyżej jedna iteracja poprawek, FAIL w
iteracji 2 otwiera eskalację. wydanie: eskalacja po FAIL w iteracji 3. 08-qa nie ma review: kod 4.
Powtórka dla tego samego review nic nie zmienia.
```

## decision

```text
Użycie: shctl decision add --co "..." --dlaczego "..." --cofniecie "..." [--rola ROLA]

Dopisuje wiersz do docs/decyzje.md (Data | Źródło | Pytanie | Decyzja): Źródło to --rola
(domyślnie orkiestrator; akceptacje i zgody: wlasciciel), Pytanie to --co, Decyzja to
„DLACZEGO. Cofnięcie: COFNIECIE”. Ta sama decyzja nie trafia do pliku drugi raz, także innego dnia.
Wynik JSON: wiersz, dodano.
```

## escalate

```text
Użycie: shctl escalate --dotyczy "#NR|ETAP" --powod "..." --sytuacja "..." --sprawdzono "..."
                       --potrzebne "..." [--opcje "A;B"]
                       [--priorytet high] [--akceptacja] [--typ blokada|pytanie]
        shctl escalate close E-NNN --odpowiedz "..."

Otwarcie: docs/07-realizacja/escalations/E-NNN.md (frontmatter ze stanem), etykieta
status:escalated na issue albo status escalated etapu, odświeżony docs/Projekt.md („Czeka na
Ciebie”) i notify.sh (domyślnie high). Numeracja E-NNN jest jedna dla projektu. Wywołanie z
worktree zapisuje plik w głównej kopii projektu (musi stać na main); commit robi orkiestrator.
Eskalacja zadania zwalnia slot: panel worker:NAZWA:NR dostaje etykietę eskalacja:NAZWA:NR.

  --sytuacja         wymagane, niepuste: sekcja „Sytuacja” (co się dzieje i gdzie: plik, test, PR)
  --sprawdzono       wymagane, niepuste: sekcja „Co już sprawdzono” (co przeczytano, co próbowano,
                     z jakim wynikiem); brak albo same spacje: kod 2, bez pliku i powiadomienia
  --akceptacja       decyzja do akceptacji właściciela (np. podniesienie trybu); powiadomienie
                     „Czeka na Twoją akceptację: NAZWA / podniesienie trybu”
  --typ pytanie      pytanie workera o UX albo regułę biznesową spoza karty funkcji i issue: bez
                     zmiany etykiet i statusu, bez zwolnienia slotu, powiadomienie default;
                     z --akceptacja: kod 2

Powtórka z tym samym --dotyczy i --powod dotyczy tej samej otwartej eskalacji. Nieudane
powiadomienie: kod 1, ponowienie wysyła je jeszcze raz.

close: odpowiedź w sekcji „Rozstrzygnięcie”, poprzedni status issue lub etapu, wpis znika z
Projekt.md. Powtórka z tą samą odpowiedzią nic nie zmienia, z inną: kod 4.
Wynik JSON: id, typ, dotyczy, plik, katalog, z_worktree, nowa, slot_zwolniony, panel.
```

## status

```text
Użycie: shctl status show

Tylko czyta. Stan projektu dla właściciela: „Gdzie jesteśmy” i „Czeka na Ciebie” z
docs/Projekt.md, zadania według statusu (z GitHuba, bez sieci z docs/06-zadania/index.md), otwarte
eskalacje i pytania, wstrzymania z /Users/Shared/sh/limity.md. JSON: gdzie, czeka (z czasem z
/Users/Shared/sh/stan/czeka/NAZWA.json), projekt, tryb, etap, zadania, zrodlo_zadan, eskalacje,
wstrzymania.
```

## stop-all

```text
Użycie: shctl stop-all [--projekt NAZWA]

Awaryjny stop. Zamyka panele herdr agentów, zachowuje worktree, zapisuje stan w
/Users/Shared/sh/stan/NAZWA.json (panele, etap, gałąź, HEAD, niezacommitowane pliki, worktree) i
wysyła notify.sh high „STOP”. Niczego nie wznawia: po STOP właściciel uruchamia orkiestratora i
pisze „wznów”.

  bez --projekt    panele worker:, review:, qa:, eskalacja:, orkiestrator:NAZWA, wspólny
                   orkiestrator i agenci z katalogiem w projektach
  --projekt NAZWA  tylko panele tego projektu; wspólny orkiestrator zostaje

Panele bez agenta (np. powloka) zostają. Panel, z którego działa shctl, zamyka się na końcu.
--dry-run wypisuje kolejność (pole kolejnosc).
```

## skrzynka

```text
Użycie: shctl skrzynka przyjmij NAZWA

Skrzynka to zwykły folder Obsidian Vault/SH/Skrzynka/NAZWA (SH_SKRZYNKA_DIR) na materiały
właściciela: makiety, eksport z Claude Design, logo, teksty. Zakłada ją new-project albo
obsidian link. przyjmij w jednym wywołaniu:

  1. kopiuje pliki do docs/00-intake/zrodla (podkatalogi zostają, prawa 644); pomija pliki ukryte,
     __MACOSX i dowiązania;
  2. gałąź skrzynka/RRRRMMDD-HHMMSS w worktree /Users/Shared/sh/wt/NAZWA, commit, push i PR;
  3. czeka na CI (pr check --czekaj);
  4. przy zielonym CI merguje PR (squash) i opróżnia skrzynkę.

Bez review modelu i akceptacji właściciela (decyzja właściciela z 2026-11-03). Pliki to dane
nieufne: komenda ich nie uruchamia ani nie rozpakowuje. Czerwone CI: kod 4, PR otwarty, skrzynka
bez zmian. Pusta skrzynka: stan pusto. Brak skrzynki: kod 3. --dry-run: lista plików.
Wynik JSON: stan (przyjeto, pusto, do_przyjecia), pr, url, pliki.
```

## obsidian

```text
Użycie: shctl obsidian link NAZWA
        shctl obsidian unlink NAZWA

link: lekki klon docs/ projektu w SH_OBSIDIAN_DIR/NAZWA (git clone --filter=blob:none --sparse,
sparse-checkout /docs/) i skrzynka na materiały, jeśli ich brak; to samo robi new-project. Klony
aktualizuje co 5 minut obsidian-sync.sh (LaunchAgent), nie shctl. Katalog będący czymś innym niż
klon tego repo: kod 4.

unlink: usuwa klon przy archiwizacji; odmawia (kod 4) przy niezacommitowanych zmianach, plikach
nieśledzonych i niewypchniętych commitach. Skrzynki nie usuwa. Brak klonu: sukces bez zmian.

SH_OBSIDIAN_DIR pochodzi ze zmiennej środowiska albo z linii w ~/.config/sh/config (czytanej jako
dane, bez source).
```

## doctor

```text
Użycie: shctl doctor [--test-notify]

Zdrowie serwera. Kontrole: katalog SH (/Users/Shared/sh, uprawnienia 700, bez segmentu z kropką),
narzędzia, logowania gh, codex i claude, logowanie git do GitHuba (helper z install.sh), Docker,
serwer herdr, orkiestrator (claude remote-control w panelu orkiestrator, ta sama kontrola co
sh-start.sh i strażnik) i /Users/Shared/sh/bin w jego PATH, notify.sh i temat ntfy, globalny
core.hooksPath, lokalny core.hooksPath w projektach, wolne miejsce, porty.md, klony Obsidiana
(czyste i zgodne z origin) oraz repo testowe z /Users/Shared/sh/stan/do-usuniecia.md.

Stany: ok, uwaga, blad; tylko blad daje kod 1. Jedyny zapis: zdejmuje z listy do usunięcia repo,
których już nie ma (przy --dry-run tylko wskazuje). --test-notify wysyła prawdziwe powiadomienie.
Orkiestrator uruchamia doctor przed pierwszym task dispatch projektu: blad wstrzymuje dispatch.
Wynik JSON: bledy, kontrole (nazwa, stan, szczegoly).
```

## task

```text
Użycie: shctl task create --plik zadania.yaml
        shctl task ready [--czekaj] [--timeout SEKUNDY]
        shctl task dispatch NR
        shctl task wait NR [--timeout SEKUNDY]
        shctl task iter NR [--odbior "kryterium"]
        shctl task close NR [--odbior] [--anuluj [--powod "..."]]
        shctl task resume-check NR [--testy "..."] [--bez-testow]
        shctl task deps NR [--usun #X]... [--dodaj #X]...
        shctl task polecenie NR "tekst"

Cykl zadania: create -> ready -> dispatch -> wait (PR z raportem) -> pr check --czekaj ->
review run -> przy FAIL iter i znów review run -> close. Po przerwie: resume-check.
Worktree /Users/Shared/sh/wt/NAZWA/NR, gałąź task/NR-slug, panel herdr worker:NAZWA:NR, stan w
/Users/Shared/sh/stan/NAZWA.json. Etap A: runner:local, wykonawca:claude.

create: issue z pliku YAML (lista albo klucz zadania). Pola: id, tytul, cel, kryteria (wymagane),
  pliki, testy, zaleznosci (ID z pliku albo "#NR"), typ (feature|bug|qa|docs|cr), tryb (S|M),
  db_migracja, milestone, waga (krytyczne|istotne|drobne; typ qa tylko krytyczne albo istotne),
  kategoria (frontend|backend|baza|integracje|bezpieczenstwo|testy|ci|ai-dane|refaktoryzacja),
  stack, skille, widoczne. Etykiety status:todo, runner:local, wykonawca:claude, typ:X i
  opcjonalne. „Zakres” zawsze wymienia też raport docs/07-realizacja/T-NR.md. Znaczniki shctl:id i shctl:warstwy w treści, brakujące milestone'y, mapa w
  docs/06-zadania/index.md. Błędne pole, zależność albo cykl: kod 2 przed jakąkolwiek zmianą.
  Issue z tym samym ID: w status:todo aktualizowane według pliku (tytuł, treść, etykiety typu,
  milestone; pole zaktualizowane), bez duplikatu; w toku albo zamknięte o innym tytule: kod 4.
ready: tylko czyta. gotowe = kandydaci (status:todo, zależności zamknięte; najwyżej jedno zadanie
  db:migracja naraz), gdy nie ma blokad: slot max_local (Mac i projekt), wolne miejsce poniżej
  min_wolne_gb (15), kolejka review max_review_queue (3), limit Claude w limity.md, niekompletna
  docs/00-intake/lista-startowa.md (pola „- [ ]” poza blokami kodu i komentarzami HTML).
  --czekaj sprawdza blokady co 30 s do --timeout (1800 s). Kolejność: najpierw ścieżka krytyczna
  (pole sciezka: najdłuższy łańcuch otwartych zadań od zadania), potem numer.
  Zależności to tylko lista „#NR, #NR” w pierwszej niepustej linii sekcji „### Zależności”; notatki
  pod nią i wzmianki w innych sekcjach się nie liczą. Zależność anulowana (not planned) blokuje z
  propozycją: shctl task deps NR --usun #X albo eskalacja.
dispatch: te same bramki, potem worktree, kopia .env.local i env_files, zaufanie folderu w
  ~/.claude.json, fnm install przy .nvmrc, lista skilli workera (warstwy niżej), karta herdr z
  claude --settings .claude/roles/worker/settings.json i poleceniem „Zrealizuj issue #NR skillem
  sh-worker”, etykiety status:in-progress i iter:1. Przy in-progress dokańcza brakujące kroki.
  CI na main (ostatni bieg każdego workflow, gh run list): czerwone to ostrzeżenie na stderr i w
  poleceniu workera (nie diagnozuje cudzego błędu), nie blokada. Pole main_ci: stan
  (zielone|czerwone|brak|nieznane), czerwone (nazwy workflow).
wait: czeka na nową turę workera po poleceniu. Stany: gotowe (PR z Closes #NR, commit po poleceniu
  zmieniający raport docs/07-realizacja/T-NR.md i agent, który już nie pracuje), idle, pracuje,
  bez_tury, blocked, brak_agenta, brak_panelu. Pierwszy commit przy pracującym agencie nie kończy
  czekania. Domyślnie 600 s; pole nastepny_krok podpowiada dalszy krok.
iter: tylko po FAIL review bieżącego commita. iter:N -> iter:N+1, status:in-progress, polecenie
  dla workera: popraw tylko zgłoszenia 🔴 i 🟡. FAIL w iteracji 3 otwiera eskalację.
iter --odbior "kryterium": zmiana zgłoszona przez właściciela przy odbiorze, także po PASS. Dopisuje
  „- [ ] kryterium (odbiór DATA)” do sekcji „Kryteria z odbioru” w issue, ustawia status:in-progress
  i wysyła workerowi polecenie; licznika iteracji nie zmienia. close odmawia (kod 4), dopóki w PR nie
  ma nowego commita po tym poleceniu. Powtórka z tym samym kryterium niczego nie dubluje.
close: w repo głównym na main. Merge (squash) tylko przy zielonym CI (wszystkie biegi workflow
  commita zakończone, jak w pr check) i PASS dla bieżącego commita;
  zlecenie S wymaga --odbior (po „odbieram #NR”), chyba że ma widoczne:nie przy odbior_S:
  auto_bez_zmian_widocznych. Potem: Decyzje z raportu do decyzje.md, Drobne uwagi i ⚪ z review
  do backlog-drobne.md, wiersz metryk, „Niewydane” w CHANGELOG.md, Propozycje dla systemu jako
  komentarz w issue miesiąca „Propozycje RRRR-MM” w sh-system, linia „PR: #N” w raporcie T-NR.md
  (worker nie robi drugiego commita z numerem); usuwa worktree, gałąź i panel.
  Plików wspólnych nie commituje.
close --anuluj: zamyka PR z gałęzią, panele, worktree i issue jako „not planned” z powodem.
  Scalony PR: kod 4. Dawne task cancel NR działa jako alias z ostrzeżeniem.
resume-check: stan po przerwie (status, iteracja, panel, gałąź, HEAD, niezacommitowane pliki,
  commity za i przed origin/main, wynik testów z „Komendy testów” issue albo --testy).
  Nie zmienia etykiet: przerwanie przez limit nie jest iteracją. Pole sugestia to podpowiedź.
deps: zależności zadania z pola strukturalnego; --usun i --dodaj przepisują linię listy („#1, #2”
  albo „brak”, notatki pod nią zostają), dodają komentarz w issue i odświeżają widok. Bez opcji
  tylko odczyt. Zależność od siebie: kod 2; nieistniejące issue: kod 3.
polecenie: dowolne polecenie orkiestratora dla workera w toku (naprawa CI, konflikt, dokończenie,
  odpowiedź na pytanie). Panel po etykiecie worker:NAZWA:NR (po eskalacji eskalacja:NAZWA:NR), bez
  panelu przy istniejącym worktree: nowy panel z claude. Zapisuje czas polecenia, więc task wait NR
  czeka potem na nową turę. Zamiast herdr agent prompt (nie zna etykiet: agent_not_found).
  Licznik iteracji bez zmian. Pusta treść albo brak: kod 2; zamknięte issue: kod 4.

Warstwy skilli workera (plugin/warstwy-skilli.yaml): bazowe, kategoria (sh-kat-NAZWA), stack
(sh-stack-NAZWA), skille z zadania, skille projektu (.claude/skills). Brakujący skill z pola
skille zadania: pole skille_brak i ostrzeżenie. Brakujący skill kategorii albo stacku: bez
komunikatu przy dispatchu, tylko w stanie projektu; raz, zbiorczo, przez shctl metryki skille. Skille techniczne (plugin/skills/techniczne) idą do polecenia jako ścieżki do
przeczytania; przy sprzeczności wygrywa projekt, potem stack, kategoria, bazowe.

Z docs/konfiguracja.md: max_local (tylko obniża limit z /Users/Shared/sh/konfiguracja.md),
max_review_queue, min_wolne_gb, env_files, modele.worker (opus).
limity.md: wpis ze słowem codex wstrzymuje review, każdy inny workerów Claude; „brak” to brak.
```

## pr

```text
Użycie: shctl pr check PR [--czekaj] [--timeout SEKUNDY]

Stan PR przed czekaniem na CI. Najpierw mergeable: przy CONFLICTING GitHub nie uruchamia CI, więc
kod 4 z komunikatem o konflikcie (rozwiązuje autor gałęzi: git pull --no-rebase origin main w
worktree, bez konfliktu gh pr update-branch). Potem CI: pass, fail, pending albo brak; z --czekaj
czeka do rozstrzygnięcia (1800 s, przy braku CI 180 s). pass dopiero, gdy wszystkie joby są
zakończone: poza statusCheckRollup sprawdza biegi workflow commita (gh run list --commit), bo job
czekający na inny (needs) nie ma jeszcze checku. Pominięte joby (SKIPPED) liczą się jak zaliczone.

Dla PR zadania liczy czerwone commity: pierwszy to wynik pracy, kolejne to próby naprawy. Po 2
nieudanych naprawach zwraca limit_napraw_ci: true (dalej review albo eskalacja, decyduje
orkiestrator). Commit zmieniający względem poprzedniego czerwonego tylko raport T-NR.md nie jest
próbą naprawy.
Wynik JSON: pr, nr, head, mergeable, konflikt, ci, czerwone_commity, nieudane_naprawy_ci,
limit_napraw_ci, nastepny_krok.
```

## review

```text
Użycie: shctl review run PR [--timeout SEKUNDY]

Niezależne review w świeżej sesji (skill sh-review), jedno naraz dla PR. PR z Closes #NR albo
gałęzi task/NR- to review zadania; PR z gałęzi stage/ETAP to review etapu (DoD.md etapu, iteracja
z DoD.md na main). stage/08-qa: kod 4 (raport QA bez review, merge po zielonym CI).

Silnik według ryzyka PR (/Users/Shared/sh/konfiguracja.md, klucz review; projekt nadpisuje pole po
polu w docs/konfiguracja.md):
  review.zwykle     claude, opus, medium        PR bez ryzyka
  review.ryzyko     codex, gpt-6-astra, high    PR z ryzykiem
  review.gdy_limit  czekaj | drugi_silnik       limit silnika: PR czeka w status:review albo
                                                review robi drugi silnik
  review.prog_linii 400                         większy diff to ryzyko
Ryzyko: kategoria baza albo bezpieczenstwo, backend z autoryzacją w issue, pliki auth, migracji,
sekretów, CI lub uprawnień, diff powyżej progu. PR zadania tylko z docs/** i *.md (bez AGENTS.md,
CLAUDE.md, .claude/, .github/) dostaje „Review shctl: PASS” bez modelu.

Kolejno: status:review na issue, ocena ryzyka i iteracji, czysty worktree
/Users/Shared/sh/wt/NAZWA/review-NR bez plików env (.env* w PR: kod 4), panel review:NAZWA:NR,
silnik tylko do odczytu (Codex: profil reviewer, -s read-only; Claude: claude -p z
.claude/roles/reviewer/settings.json z main projektu), komentarz w PR z werdyktem, zgłoszeniami
🔴🟡⚪ i metrykami, sprzątanie worktree i panelu. Prompt: skill sh-review, kontekst issue jako
dane, w iteracji 2+ diff od poprzedniego review i poprzednie zgłoszenia, listy kontrolne skilli
kategorii i stacku zadania (przy migracjach także sh-kat-baza).

Werdykt liczy shctl: FAIL przy 🔴 albo 🟡, inaczej PASS; kod 0 przy obu. PASS dotyczy tylko
commita: nowy push wymaga nowego review. Powtórka dla tego samego commita zwraca wynik z
komentarza (ponownie: true). Limit silnika: push z godziną odnowienia. Metryki także w
/Users/Shared/sh/stan/review/metryki.jsonl. --dry-run zwraca profile i gdy_limit.
```

## reset-dryrun

```text
Użycie: shctl reset-dryrun

Przywraca projekt wzorcowy sh-dryrun (SHCTL_DRYRUN_NAZWA) do tagu baseline: baseline_tag z
docs/konfiguracja.md albo najnowszy baseline-RRRRMMDD. Tagów nie przesuwa. Inny projekt: kod 4.
Tag z artefaktami przebiegu (raporty T-NR.md, eskalacje, raporty QA, mapa zadań, wpisy
CHANGELOG.md, DoD.md poza todo/pominiety): kod 4 z listą.

Kolejno: zachowuje docs/metryki.md, zamyka panele, worktree i otwarte PR, archiwizuje znaczniki
shctl:id we wszystkich issue (otwarte zamyka jako „not planned”), resetuje main do tagu (push
--force-with-lease), w procesie v1 (wersja_procesu w konfiguracji tagu) odtwarza issue przez task
create z zadania.yaml tagu; w v2 nie zakłada issue: zadania powstają z planu po etapie 06-zadania.
Dodaje sekcję „Przebieg dryrun N” w metrykach (N = numer ostatniej sekcji + 1), odświeża widok
projektu (Projekt.md liczy zadania od nowej sekcji), commituje i wypycha main, zakłada od nowa klon
docs/ w Obsidianie. Stan zgodny z tagiem: nic nie robi (zmiana: false).
```

## template

```text
Użycie: shctl template update [--baseline] [--force]

Aktualizuje w projekcie pliki zarządzane przez szablon (scripts/, .github/workflows/,
.claude/roles/, AGENTS.md, docs/_szablony/) z main sh-template-projekt.

  plik równy bieżącemu szablonowi              nic
  plik równy którejś wersji z historii         aktualizacja
  plik zmieniony w projekcie                   pominiety, z --force nadpisany
  brak pliku w projekcie                       nowy
  plik usunięty z szablonu                     zostaje

Klon projektu musi stać na czystym main zgodnym z origin (inaczej kod 4). Zmiany trafiają do
commita „szablon: pliki z SH_TEMPLATE SHA” na main i push. --baseline (projekt wzorcowy): to samo
na najnowszym baseline i nowy tag baseline-RRRRMMDD bez force. Zadania w toku dostają nowe pliki po
merge'u main do swojej gałęzi. --dry-run tylko porównuje.
```

## sprzataj

```text
Użycie: shctl sprzataj

Usuwa worktree w /Users/Shared/sh/wt-system/ i /Users/Shared/sh/wt/ oraz lokalne gałęzie repo w
/Users/Shared/sh i /Users/Shared/sh/projekty wyłącznie wtedy, gdy PR gałęzi ma stan MERGED albo
CLOSED. Nigdy z --force. Zostają (pole pominiete z powodem): gałąź bez PR albo z otwartym PR,
worktree z niezacommitowanymi zmianami, gałąź z commitami spoza head PR, gałąź wybrana w worktree;
main i gałąź bieżąca bez wpisu. Repo bez origin (np. lokalne sh-test) i jego worktree zostają z
powodem „repo bez origin”; sprzątanie reszty trwa. Gałęzie usuwa skrypt przez git branch -D (po squash merge -d
odmawia); agent nie usuwa gałęzi sam. Gałąź bez PR usuwa właściciel.
Wynik JSON: worktree, galezie, pominiete.
```

## metryki

```text
Użycie: shctl metryki serwer [--probki N] [--co SEKUNDY]
        shctl metryki skille [--projekt NAZWA]

Obciążenie Maca do metryk przebiegu: load (1, 5, 15 min), swap (zajęty i całkowity, MB), wolne
miejsce na dysku z SH_DIR (GB) i liczba rdzeni. Bez projektu, tylko odczyt. Orkiestrator woła ją
zamiast sysctl i df: shctl działa poza sandboxem sesji SH, a sysctl w sandboxie jest zablokowany.
Odczyty w LC_ALL=C (sysctl w polskim locale daje przecinek dziesiętny, np. „6,50”).

--probki N   N próbek co --co sekund (domyślnie 1 próbka, co 30 s); wynik to ostatnia próbka i
             load_m1 {srednia, maks} ze wszystkich

skille: brakujące skille warstw kategorii i stacku, które task dispatch zebrał w bieżącym
przebiegu (stan/NAZWA.json; reset-dryrun czyści). Wynik: brak (lista), zadania (skill -> numery
zadań) i linia do raportu przebiegu, np. „Brakujące skille warstw (zbiorczo, 2): sh-kat-ci (#97);
sh-stack-node (#97, #98)”.
```
