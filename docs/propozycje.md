# Propozycje dla systemu

Zbiera `shctl task close` z raportów zadań (sekcja „Propozycje dla systemu”). Decyzję podejmuje retro.

## sh-system (2026-11-02): shctl cykl new, etap B

Drugie zlecenie M w trwającym projekcie nie ma dziś mechaniki: etapy `00-intake`, `04-architektura`,
`05-plan`, `06-zadania`, `07-realizacja`, `08-qa` i `wydanie` mają po pierwszym zleceniu status `done`,
a `shctl stage start` nie przyjmuje statusu `done`. Specyfikacja i plan są pojedynczymi plikami.

Propozycja na etap B: `shctl cykl new SLUG`, który otwiera nowy cykl zlecenia M w tym samym repo:
archiwizuje dokumenty poprzedniego cyklu (np. `docs/cykle/NN-slug/`), zeruje `DoD.md` etapów trybu M
do `todo` z `iteracja: 0`, zapisuje cykl w `status.md` i w `metryki.md` oraz zostawia `decyzje.md`,
`CHANGELOG.md` i `AGENTS.md` bez zmian.

Do tego czasu `sh-intake` proponuje właścicielowi podział na zlecenia S albo osobny projekt.

## sh-system (2026-11-02): drobne uwagi z raportu QA do backlogu

`shctl task close` przenosi „Drobne uwagi” z `T-NR.md` do `docs/backlog-drobne.md`, ale raport QA
`docs/08-qa/raport-MN.md` nie ma takiej komendy, więc orkiestrator dopisuje wiersze ręcznie.

Propozycja: `shctl qa close MN` (albo krok w `stage`), który czyta „Drobne uwagi” z
`raport-MN.md` tym samym parserem co `task close` i dopisuje `| DATA | QA MN | uwaga | otwarta |`
bez dublowania.


## sh-system (2026-11-02): komendy dla orkiestratora

`sh-orkiestrator` wykonuje dziś ręcznie operacje, których shctl nie ma:

- merge PR etapu (`gh pr merge PR --squash --match-head-commit SHA`) po zielonym CI, PASS i
  akceptacji właściciela; propozycja: `shctl stage merge PR` z tymi samymi bramkami co `task close`;
- pola Checkpointu w `DoD.md` na `main` (review z komentarza PASS, akceptacja z wiersza `wlasciciel`
  w `decyzje.md`), podbicie `iteracja` etapu po FAIL i zgłoszenia ⚪ z review etapu do
  `backlog-drobne.md`; propozycja: kroki w `stage merge` i `stage iter ETAP`;
- polecenie dla działającego workera (dokończenie zadania, iteracja od nowa po limicie) przez
  `herdr agent prompt`; propozycja: `shctl task nudge NR --powod kontynuuj|od-nowa`;
- wpis „Punktu przekazania” w `status.md`; propozycja: `shctl handoff` z danymi `status show`,
  wynikiem `doctor` i wierszem autoryzacji.

## sh-dryrun T-8 (2026-11-04)

<!-- propozycje:sh-dryrun:T-8 -->
- Profil workera nie pozwala na `fnm` ani `cat`/`head`; dodać `Bash(fnm list)` / `Bash(fnm current)`, żeby worker mógł sprawdzić wersję Node zgodnie z kontraktem „Node LTS przez fnm”.
- Szablon CI mógłby od razu zawierać przypięte SHA `pnpm/action-setup` i `actions/setup-node` (zakomentowane), bo worker nie ma `gh api` i musi szukać SHA przez WebFetch.
- Przenieść poprawkę `scripts/tests/sync-status.bats` z fixture'ami (`scripts/tests/fixtures/sync-status/`) do `sh-template-projekt`; bez niej każdy nowy projekt ma czerwony `testy-skryptow` po pierwszych wpisach orkiestratora.
- Dodać `Bash(bats *)` do profilu workera, żeby worker mógł lokalnie uruchomić testy skryptów przed pushem.
- Zadanie szkieletu powinno mieć w „Zakresie” `src/**` i `tsconfig.build.json` (albo ogólnie katalog kodu), skoro kryterium wymaga kodu w `src/`.

## sh-dryrun T-11 (2026-11-04)

<!-- propozycje:sh-dryrun:T-11 -->
- Profil workera nie pozwala na `gh pr list` ani złożone komendy Bash (`;`), więc stan PR przy starcie sprawdziłem tylko przez `git log origin/main..HEAD`. Dodać `Bash(gh pr list *)` albo opisać w skillu, że do sprawdzenia PR służy `gh pr view`.
- Zadania dodające nowy moduł biblioteki powinny mieć w „Zakresie” `src/index.ts`, jeśli funkcja ma trafić do publicznego API.

## sh-dryrun T-13 (2026-11-04)

<!-- propozycje:sh-dryrun:T-13 -->
- Profil workera blokuje złożone polecenia powłoki (np. kilka komend przez `;`). Krok 1 Procedury
  wygodniej byłoby opisać jako osobne polecenia albo dodać `shctl task whereami` zwracające katalog,
  gałąź, iterację i numer PR w jednym JSON.

## sh-dryrun T-9 (2026-11-04)

<!-- propozycje:sh-dryrun:T-9 -->
- Profil workera nadal blokuje złożone polecenia powłoki (`;`, `&&`) i część prostych (np.
  `git rev-list --left-right --count`). Krok 1 i 4 Procedury wymagają kilku osobnych wywołań; przydałoby
  się `shctl task whereami` (katalog, gałąź, iteracja, PR, liczba commitów za `main`) w jednym JSON.
- Numer PR do raportu znany jest dopiero po `gh pr create`, więc raport wymaga drugiego commita.
  Szablon mógłby dopuszczać `PR:` uzupełniane przez `shctl review run` albo `task close`.

## sh-dryrun T-10 (2026-11-04)

<!-- propozycje:sh-dryrun:T-10 -->
- Numer PR do raportu znany jest dopiero po `gh pr create`, więc raport wymaga drugiego commita.
  Szablon mógłby dopuszczać `PR:` uzupełniane przez `shctl review run` albo `task close`.
- Profil workera nadal odrzuca złożone polecenia powłoki (`&&`, heredoc), więc commit, push i
  `gh pr create` trzeba wywoływać osobno; warto to opisać w skillu albo poluzować profil.

## sh-dryrun T-23 (2026-11-04)

<!-- propozycje:sh-dryrun:T-23 -->
- Profil workera: dopuścić `git ls-remote --tags https://github.com/*` (tylko odczyt), żeby zadanie szkieletu mogło przypinać akcje GitHub po SHA bez obchodzenia przez WebFetch.
- Przenieść poprawkę `scripts/tests/sync-status.bats` (fixture'y zamiast kopii żywego `docs/`) do `sh-template-projekt`, żeby nowe projekty nie miały czerwonego CI po pierwszej decyzji orkiestratora.
- Profil workera: dopuścić `bats scripts/tests/*`, żeby worker mógł lokalnie sprawdzić testy skryptów przed pushem.
- Szablon CI: dać od razu przypięty `actions/setup-node` (zakomentowany), skoro większość projektów to Node.

## sh-dryrun T-26 (2026-11-04)

<!-- propozycje:sh-dryrun:T-26 -->
- Profil workera odrzuca złożone komendy Bash (`&&`, `;`), więc komendy z „Komendy testów” i DoD trzeba uruchamiać pojedynczo; warto to opisać w skillu sh-worker.

## sh-dryrun T-24 (2026-11-04)

<!-- propozycje:sh-dryrun:T-24 -->
- Profil workera nie pozwala na `gh pr list`; sprawdzenie istnienia PR robię przez `gh pr view task/NR-slug`, co skill już opisuje, ale warto to podkreślić. Złożone komendy Bash (`;`, `&&`) są nadal odrzucane (jak w T-26).

## sh-dryrun T-25 (2026-11-04)

<!-- propozycje:sh-dryrun:T-25 -->
- Issue wskazuje specyfikację i architekturę z „Wejścia” skilla, których w projekcie typu biblioteka nie ma; warto, żeby `sh-zadania` wpisywał w issue „brak specyfikacji/architektury”, a skill nie wymagał ich czytania.

## sh-dryrun T-28 (2026-11-04)

<!-- propozycje:sh-dryrun:T-28 -->
- Narzędzie Write zapisało znak U+00A0 wpisany dosłownie w kodzie jako zwykłą spację, co dało mylący błąd testu („expected … to deeply equal …” przy identycznym wyglądzie). Warto zalecić w skillu sh-worker zapis znaków niewidocznych przez escape (`" "`).

## sh-dryrun T-36 (2026-11-04)

<!-- propozycje:sh-dryrun:T-36 -->
- Narzędzie Write/Edit zamieniało w teście sekwencję ` ` na literalny znak, co blokował eslint.
  Warto w szablonie testów zalecać `\s` zamiast ` ` w wyrażeniach regularnych.

## sh-dryrun T-38 (2026-11-04)

<!-- propozycje:sh-dryrun:T-38 -->
- Profil workera blokuje `gh api` (np. odczyt wydań akcji GitHub). Przy przypinaniu akcji do SHA w zadaniu szkieletu przydałby się dozwolony odczyt `gh api repos/*/releases` albo gotowa lista SHA w szablonie `ci.yml`.
- Szablon `ci.yml` mógłby od razu zawierać kroki `pnpm/action-setup` i `actions/setup-node` z przypiętymi SHA dla projektów Node; zadanie szkieletu podmieniałoby tylko komendy.

## sh-dryrun T-41 (2026-11-04)

<!-- propozycje:sh-dryrun:T-41 -->
- Lista plików w „Zakresie” issue mogłaby zawsze zawierać `docs/07-realizacja/T-NR.md`, żeby raport nie wymagał decyzji „plik spoza Zakresu”.

## sh-dryrun T-43 (2026-11-04)

<!-- propozycje:sh-dryrun:T-43 -->
- Jak w T-41: lista plików w „Zakresie” issue mogłaby zawsze zawierać `docs/07-realizacja/T-NR.md`.
- Raport wymaga numeru PR, który powstaje dopiero po `gh pr create`; worker robi drugi commit z numerem. `shctl` mógłby wpisywać `PR: #N` sam albo szablon mógłby dopuszczać jego uzupełnienie przez orkiestratora.

## sh-dryrun T-51 (2026-11-05)

<!-- propozycje:sh-dryrun:T-51 -->
- Szablon zadań typu biblioteka: dodać do CI krok smoke importu zbudowanego pakietu (`pnpm build` + `node -e "import … from '<nazwa>'"`), żeby kryteria dotyczące punktu wejścia miały test automatyczny.

## sh-dryrun T-53 (2026-11-05)

<!-- propozycje:sh-dryrun:T-53 -->
- Profil workera odrzuca samo `git push` (przechodzi tylko `git push -u origin task/NR-slug`).
  Skill sh-worker mówi „push go aktualizuje”; warto wprost podać pełną formę komendy.

## sh-dryrun: właściciel i orkiestrator, zlecenie S #53 (2026-11-05)

<!-- propozycje:sh-dryrun:wlasciciel-2026-11-05 -->
- Właściciel (pkt 6): `shctl review run` odmawia przy czerwonym lub trwającym CI (wyjątek:
  `limit_napraw_ci`) i zapisuje SHA commita, którego dotyczy review; `shctl task close` i merge
  odmawiają, gdy PASS dotyczy innego commita niż aktualny HEAD PR. Powód: w #53 orkiestrator uruchomił
  review przy czerwonym CI (PASS dla `caf973e`), a worker dopchnął potem 4 commity; dziś chroni przed
  tym tylko dyscyplina orkiestratora.
- Orkiestrator: `shctl task wait` po poleceniu poprawki (`herdr agent prompt`) zwraca `gotowe` od razu,
  bo PR z raportem już istnieje, a `herdr agent wait --until done` wraca od razu przy stanie `done`
  sprzed polecenia. Potrzebny warunek „nowa tura po poleceniu” (np. `completion_seq` większe niż przy
  poleceniu albo nowy HEAD PR).
- Orkiestrator: baseline `sh-dryrun` (`624bd6f`) nie ma `scripts/` z sh-template-projekt#12 i #14
  (`sync-status.bats`, `check-dod.bats` na danych testowych, `check-dod.sh` z polami `[-]` i
  `uzasadnienie_pominiecia`), a projekt ma `max_local: 1`. Każdy przebieg naprawia to w szkielecie;
  baseline warto odświeżyć z szablonu.

## iskt-www T-5 (2026-11-05)

<!-- propozycje:iskt-www:T-5 -->
- Profil workera: reguły deny z klasami `[!...]` (`Edit(.env.e[!x]*)` itd.) blokują `Edit(.env.example)`; matcher uprawnień najpewniej nie obsługuje negacji `[!x]`. Proponuję zastąpić je listą jawnych nazw albo testem bats, który sprawdza, że `.env.example` jest edytowalny.
- Szablon `.env.example`: zmienne Supabase dopisywać tylko w projektach z bazą (projekt bez bazy musi je usuwać).
- Zadanie szkieletu na pnpm 11+: szablon mógłby zawierać `pnpm-workspace.yaml` z `allowBuilds`, a issue szkieletu — ten plik w „Zakresie”.

## iskt-www T-6 (2026-11-05)

<!-- propozycje:iskt-www:T-6 -->
- Profil workera odrzuca `curl` i polecenia w tle (`&`), więc nie da się szybko sprawdzić odpowiedzi
  `astro preview`; przydałby się dozwolony `curl` na `localhost` albo wzmianka w skillu, że takie
  sprawdzenia robi się testem Playwright.

## iskt-www T-7 (2026-11-05)

<!-- propozycje:iskt-www:T-7 -->
- Kontrakt e2e ma jeden serwer z jedną konfiguracją env; dla kryteriów „dla obu wartości zmiennej”
  przydałby się w szablonie projektu drugi `webServer` (np. port produkcyjny) albo wzorzec testu z
  osobnym buildem.

## iskt-www T-9 (2026-11-05)

<!-- propozycje:iskt-www:T-9 -->
- `playwright.config.ts` w szablonie projektu: `reuseExistingServer` tylko dla serwera z tego samego
  worktree (np. wyłączone domyślnie albo port per worktree), bo równoległe worktree współdzielą port
  `preview` i testy cicho trafiają w cudzy build.

## iskt-www T-11 (2026-11-05)

<!-- propozycje:iskt-www:T-11 -->
- Profil workera: zezwolić na Edit/Write `.env.example` (skill sh-worker wymienia go w „Wyjściu”, a
  profil blokuje wszystkie `.env*`), zostawiając blokadę `.env`, `.env.local` i `.env.prod*`.
- Profil workera: zezwolić na prefiks zmiennych środowiskowych (`VAR=x pnpm …`) przy `pnpm`, żeby dało
  się uruchomić serwer podglądu z inną konfiguracją do debugowania, bez obchodzenia przez testy.
- Szablon zadania spike'a: gdy kryterium wymaga stagingu/panelu Vercel, issue powinno podać adres
  preview i stan reguły albo przypisać sprawdzenie do QA/właściciela.

## iskt-www T-23 (2026-11-05)

<!-- propozycje:iskt-www:T-23 -->
- Szablon CI: job `e2e` instaluje zależności systemowe przeglądarek przez apt przy każdym runie, więc wolny mirror przekracza `timeout-minutes: 20`. Warto dodać cache `~/.cache/ms-playwright` albo kontener `mcr.microsoft.com/playwright` w wersji z `konfiguracja.md`. Warto też pozwolić workerowi na `gh run rerun --failed` dla awarii infrastruktury.
- Szablon zadań QA z kryterium „na stagingu curl …” mógłby oznaczać je jako sprawdzane po merge'u (przez orkiestratora albo QA), bo worker nie ma deployu stagingu przed merge'em, a preview PR-a jest za Vercel Deployment Protection.
- Profil workera pozwala na `git rebase`, a nie na `git merge`, choć skill w kroku 12 każe robić `git merge origin/main`. Warto ujednolicić jedno albo drugie.
- Szablon projektu: osobny port preview E2E na worktree albo `reuseExistingServer: false`, żeby równoległe worktree nie dzieliły serwera.

## iskt-www T-22 (2026-11-05)

<!-- propozycje:iskt-www:T-22 -->
- Szablon issue QA wydajności: dopisywać do „Zakresu” `public/` (fonty, obrazy), bo wynik mobile w
  Lighthouse zwykle zależy też od fontów, nie tylko od komponentów i CSS.
- Kryterium „wynik na stagingu po merge'u” jest niesprawdzalne przez workera; lepiej: „lokalnie na
  `astro preview` przed PR, na stagingu w QA po merge'u”.

## iskt-www T-29 (2026-11-05)

<!-- propozycje:iskt-www:T-29 -->
- Kryteria wymagające pomiaru „po merge'u” (np. Lighthouse na stagingu) nie mogą być spełnione przez
  workera przed review. Propozycja: w szablonie issue oznaczać takie kryteria jako weryfikację
  orkiestratora/QA po merge'u albo dodać krok `shctl` do pomiaru po merge'u.
- Profil workera nie pozwala na `gh run rerun`, więc ponowienie CI przerwanego przez infrastrukturę
  wymaga nowego commita. Propozycja: dopuścić `gh run rerun --failed` dla gałęzi `task/*` oraz
  cache przeglądarek Playwright w CI, żeby nie instalować zależności apt przy każdym przebiegu.

## iskt-www T-10 (2026-11-05)

<!-- propozycje:iskt-www:T-10 -->
- Profil workera nie pozwala na `git check-ignore` ani na kilka wariantów `gh` (`gh issue list`). Do
  sprawdzenia ignorowanych plików musiałem użyć `git status --ignored`. Warto dopisać `git check-ignore`
  do listy dozwolonych.
- Gdy na `main` jest czerwony lint albo typecheck (jak #29), `shctl task dispatch` mógłby ostrzegać
  workera przed startem, żeby nie diagnozował cudzego błędu.
- Profil workera odrzuca `git merge origin/main`, choć krok 12 procedury sh-worker i polecenia
  orkiestratora go przewidują. Warto dopisać `git merge origin/main` do listy dozwolonych albo w skillu
  i poleceniach przyjąć `git rebase origin/main` z `--force-with-lease`.

## iskt-www T-13 (2026-11-05)

<!-- propozycje:iskt-www:T-13 -->
- `gitleaks dir` w profilu workera skanuje cały katalog niezależnie od ścieżek i zgłasza
  ignorowane `.env.local` oraz `dist/`; w kroku 8 skilla sh-worker warto wskazać
  `gitleaks git` (historia) plus `git diff`, albo `gitleaks dir` z `.gitleaksignore` dla
  `.env.local` i `dist/`.

## iskt-www T-12 (2026-11-05)

<!-- propozycje:iskt-www:T-12 -->
- `shctl task dispatch` mógłby przydzielać workerowi port e2e (albo `playwright.config.ts` czytać
  `E2E_PORT`), żeby równoległe worktree nie dzieliły podglądu na 55327 przez `reuseExistingServer`.
- Profil workera odrzuca `fnm use` w potoku z `pnpm install`; warto dopisać `fnm` do dozwolonych.

## iskt-www T-15 (2026-11-06)

<!-- propozycje:iskt-www:T-15 -->
- Profil `.claude/roles/worker/settings.json` blokuje Edit/Write `.env.example`, a skill sh-worker
  („Wyjście”) i AGENTS.md wymagają dopisywania tam nowych zmiennych. Propozycja: wyjątek
  `allow` dla `.env.example` przy zachowaniu blokady pozostałych `.env*`.
- Lighthouse wersji z PR: preview Vercel za Deployment Protection uniemożliwia pomiar przed merge'em.
  Propozycja: bypass token preview w `.env.local` workera (tylko odczyt preview) albo stały zapis w
  procesie, że W-10 dla PR sprawdza się na buildzie lokalnym, a na stagingu po merge'u.

- Profil workera nie pozwala na prefiks zmiennej środowiskowej w poleceniu (`LH_RUNS=1 pnpm …`)
  ani przekierowanie do pliku; skrócony przebieg Lighthouse wymagał pełnego (~10 min). Propozycja:
  dopuścić `VAR=wartość pnpm …` dla zmiennych bez sekretów albo dodać to do opisu profilu w AGENTS.md.

## iskt-www T-16 (2026-11-06)

<!-- propozycje:iskt-www:T-16 -->
- `deploy-prod.sh` w szablonie: tryb dla projektów bez bazy (np. `hosting.baza: brak` w `konfiguracja.md` albo flaga `--bez-bazy`), który pomija sprawdzenie `supabase`/`docker`, `PROD_DB_URL`, backup i migracje.
- Szablon `wydanie-techniczna.md`: dodać sekcje „Środowiska” i „Kroki przejścia na domenę produkcyjną” (Branch Tracking, alias stagingu, zmienne prod), bo powtarzają się w każdym projekcie Vercel.

## iskt-www T-41 (2026-11-06)

<!-- propozycje:iskt-www:T-41 -->
- `astro preview` nie działa z adapterem Vercel, a profil workera blokuje polecenia z prefiksem
  zmiennych środowiskowych (`ASTRO_ADAPTER=node pnpm preview`). Do zrzutów i Lighthouse trzeba było
  napisać tymczasowy serwer statyczny. Propozycja: skrypt `pnpm preview:local` (adapter node, port
  55327) w szablonie projektu Astro + Vercel.
- Job e2e w CI może przekroczyć limit 20 min, gdy mirror apt jest wolny, bo
  `playwright install --with-deps` instaluje zależności systemowe przy każdym runie. Propozycja:
  cache przeglądarek Playwright (`~/.cache/ms-playwright`) albo obraz/kontener
  `mcr.microsoft.com/playwright` w CI. To zmiana CI, poza zakresem workera.
- Równoległe `pnpm test:e2e` i `pnpm lh:staging` kolidują, bo Playwright czyści `test-results/`,
  a lhci trzyma tam `.lighthouseci/`. Propozycja: katalog roboczy lhci poza `test-results/`.

## iskt-www T-43 (2026-11-06)

<!-- propozycje:iskt-www:T-43 -->
- Profil workera blokuje prefiks zmiennych środowiskowych (`ASTRO_ADAPTER=node pnpm build`), więc lokalny
  Lighthouse wymagał ręcznego startu `node dist/server/entry.mjs` po `pnpm test:e2e`. Propozycja: skrypt
  `pnpm lh:local` (build Node + serwer + `lh:staging`) w szablonie projektu.

## iskt-www T-44 (2026-11-06)

<!-- propozycje:iskt-www:T-44 -->
- Profil workera nie pozwala na `fnm use` ani `fnm exec`. Przy zmianie wersji Node worker nie może
  sprawdzić buildu na docelowej wersji lokalnie. Propozycja: dodać `fnm exec --using=* pnpm *` do
  dozwolonych poleceń.
