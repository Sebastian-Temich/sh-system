# Kontrakt wykonania terminalowego

Uzywaj dla etapu, ktory zmienia kod w repozytorium. Dokument zapisuj jako:

```text
07_Techniczne/Kontrakt wykonania projektu.md
```

Nie wpisuj sekretow. Podaj jedynie nazwy magazynow sekretow, zakresy dostepu i
bramki czlowieka.

```markdown
# Kontrakt wykonania projektu

## Workspace i repo
- Workspace Paperclip:
- Lokalna sciezka repo:
- Domyslny branch:
- Remote Forgejo (warsztat, bez mirrora):

## Izolacja pracy
- Zasada branchy: `stage/E0X` z `main` (Intake Lead); `e0x/<klucz>` z `stage/E0X` (wykonawca)
- Katalog worktree: `<repo>/../worktrees/<klucz>`
- Czy wiele agentow moze pracowac rownolegle:
- Granice modulow / wlasciciele plikow:

## Tryby wykonania
| Tryb | Kiedy dozwolony | Zakres dostepu | Dowod |
| --- | --- | --- | --- |
| claude_code_local (adapter Paperclip) | zawsze w v2 | worktree zadania, lokalny Supabase | PR + wynik komend |

## Srodowiska i dostepy
| Srodowisko | Cel | Dostep | Human gate |
| --- | --- | --- | --- |
| local (Supabase lokalny) | development, testy, podglad etapu | agenci, Board | nie dotyczy |
| production (Lovable + Supabase Cloud) | uzytkownicy | CI (baza), Board (Publish) | zawsze: merge do `main` + Publish |

## Komendy jakosci
- lint:
- typecheck:
- test:
- build:
- E2E:
- CI target:

## Merge i release
- Kto tworzy PR: wykonawca (`e0x/<klucz> -> stage/E0X`)
- Kto merguje do `stage/E0X`: QA po `accepted` i zielonym CI
- Kto merguje `stage/E0X -> main`: Board przy odbiorze etapu
- Kto zatwierdza release: Board
- Zakazane akcje: push do `main`, force push, deploy produkcyjny, polaczenie z produkcyjna baza, odczyt `.env`
```
