#!/usr/bin/env bats
load helper-zadania

setup() {
  zadania_setup
  cat >"$T/zadania.yaml" <<'YAML'
zadania:
  - id: T2
    tytul: Formularz logowania
    cel: Użytkownik loguje się e-mailem.
    kryteria:
      - formularz waliduje e-mail
      - błędne hasło pokazuje komunikat
    pliki: [src/login.ts]
    testy: pnpm test login
    zaleznosci: [T1]
    typ: feature
    tryb: M
    milestone: M1 Szkielet
  - id: T1
    tytul: Schemat bazy
    cel: Tabela users.
    kryteria: [migracja tworzy tabelę]
    db_migracja: true
    milestone: M1 Szkielet
  - id: T3
    tytul: Dokumentacja
    cel: Opis logowania.
    kryteria: [README opisuje logowanie]
    typ: docs
    zaleznosci: [T2, "#40"]
YAML
}

numer_dla() { jq -r --arg i "$1" ".wynik.mapa[\$i]" <<<"$output"; }
tresc() { jq -r --argjson n "$1" '.[] | select(.number == $n) | .body' "$GH_ATRAPA/issues.json"; }

@test "create: issue z etykietami, trescia, zaleznosciami i milestone, mapa w index.md" {
  run --separate-stderr "$SHCTL" task create --plik "$T/zadania.yaml" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  t1="$(numer_dla T1)"; t2="$(numer_dla T2)"; t3="$(numer_dla T3)"
  [ "$t1" -lt "$t2" ] && [ "$t2" -lt "$t3" ]
  [ "$(etykiety "$t1")" = "db:migracja,runner:local,status:todo,typ:feature,wykonawca:claude" ]
  [ "$(etykiety "$t2")" = "runner:local,status:todo,tryb:M,typ:feature,wykonawca:claude" ]
  [ "$(etykiety "$t3")" = "runner:local,status:todo,typ:docs,wykonawca:claude" ]
  tresc "$t2" | grep -qx -- '- \[ \] formularz waliduje e-mail'
  tresc "$t2" | grep -qx 'pnpm test login'
  tresc "$t2" | grep -qx "#$t1"
  tresc "$t3" | grep -qx "#$t2, #40"
  tresc "$t1" | grep -qx -- '- \[x\] Zadanie zawiera migrację lub reset bazy (etykieta db:migracja, realizacja pojedynczo)'
  tresc "$t1" | grep -qx '<!-- shctl:id=T1 -->'
  [ "$(jq -r '.[] | select(.title == "M1 Szkielet") | .title' "$GH_ATRAPA/milestones.json")" = "M1 Szkielet" ]
  [ "$(jq -r '.wynik.milestone_utworzone | join(",")' <<<"$output")" = "M1 Szkielet" ]
  [ "$(jq -r --argjson n "$t2" '.[] | select(.number == $n) | .milestone.title' "$GH_ATRAPA/issues.json")" = "M1 Szkielet" ]
  grep -qx "| T2 | #$t2 | Formularz logowania | #$t1 |" docs/06-zadania/index.md
  grep -qx '<!-- shctl:mapa:start -->' docs/06-zadania/index.md
  grep -q "^--repo $R" "$T/sync.calls"
}

@test "create: powtorka nie tworzy issue ani milestone drugi raz" {
  "$SHCTL" task create --plik "$T/zadania.yaml" --json >"$T/pierwszy"
  cp docs/06-zadania/index.md "$T/index"
  run --separate-stderr "$SHCTL" task create --plik "$T/zadania.yaml" --json
  [ "$status" -eq 0 ]
  [ "$(jq -c .wynik.mapa "$T/pierwszy")" = "$(jq -c .wynik.mapa <<<"$output")" ]
  [ "$(jq -r '.wynik.istniejace | length' <<<"$output")" -eq 3 ]
  [ "$(grep -c '^issue create' "$GH_ATRAPA/calls")" -eq 3 ]
  [ "$(grep -c '^api -X POST' "$GH_ATRAPA/calls")" -eq 1 ]
  cmp docs/06-zadania/index.md "$T/index"
}

@test "create: przerwane tworzenie dokancza sie powtorka" {
  touch "$GH_ATRAPA/fail-issue-create"
  run --separate-stderr "$SHCTL" task create --plik "$T/zadania.yaml"
  [ "$status" -eq 1 ]
  rm "$GH_ATRAPA/fail-issue-create"
  run --separate-stderr "$SHCTL" task create --plik "$T/zadania.yaml" --json
  [ "$status" -eq 0 ]
  [ "$(jq length "$GH_ATRAPA/issues.json")" -eq 3 ]
}

@test "create: blad z QA dostaje etykiety typ:qa i sev:WAGA" {
  printf -- '- {id: QA-M1-1, tytul: Webkit nie przekierowuje, cel: Blad z QA M1., kryteria: [panel po zalogowaniu], typ: qa, waga: istotne}\n' >"$T/qa.yaml"
  run --separate-stderr "$SHCTL" task create --plik "$T/qa.yaml" --json
  echo "$output $stderr"
  [ "$status" -eq 0 ]
  [ "$(etykiety "$(numer_dla QA-M1-1)")" = "runner:local,sev:istotne,status:todo,typ:qa,wykonawca:claude" ]
}

@test "create: bledy w YAML to kod 2" {
  printf 'zadania:\n  - id: A\n    tytul: x\n    cel: y\n    kryteria: [k]\n    zaleznosci: [B]\n' >"$T/z1.yaml"
  run --separate-stderr "$SHCTL" task create --plik "$T/z1.yaml"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"nieznana zależność B"* ]] || false
  printf -- '- {id: A, tytul: x, cel: y, kryteria: [k], zaleznosci: [B]}\n- {id: B, tytul: x, cel: y, kryteria: [k], zaleznosci: [A]}\n' >"$T/z2.yaml"
  run --separate-stderr "$SHCTL" task create --plik "$T/z2.yaml"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"cykl zależności"* ]] || false
  printf -- '- {id: A, tytul: x, cel: y, kryteria: [k], typ: zly, wykonawca: codex}\n' >"$T/z3.yaml"
  run --separate-stderr "$SHCTL" task create --plik "$T/z3.yaml"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"nieznane pole wykonawca"* ]] || false
  [[ "$stderr" == *"typ:"* ]] || false
  printf -- '- {id: A, tytul: x, cel: y, kryteria: [k], typ: qa, waga: pilne}\n' >"$T/z4.yaml"
  run --separate-stderr "$SHCTL" task create --plik "$T/z4.yaml"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"waga: krytyczne, istotne albo drobne"* ]] || false
  run --separate-stderr "$SHCTL" task create --plik "$T/brak.yaml"
  [ "$status" -eq 3 ]
  [ ! -s "$GH_ATRAPA/issues.json" ] || [ "$(jq length "$GH_ATRAPA/issues.json")" -eq 0 ]
}

@test "create: ID uzyte z innym tytulem to odmowa" {
  "$SHCTL" task create --plik "$T/zadania.yaml"
  sed -i.bak 's/Schemat bazy/Inny tytuł/' "$T/zadania.yaml"
  run --separate-stderr "$SHCTL" task create --plik "$T/zadania.yaml"
  [ "$status" -eq 4 ]
}

@test "create --dry-run: bez zmian na GitHubie i w plikach" {
  run --separate-stderr "$SHCTL" task create --plik "$T/zadania.yaml" --dry-run --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.wynik.utworzone | join(",")' <<<"$output")" = "T1,T2,T3" ]
  ! grep -qE '^(issue create|api -X)' "$GH_ATRAPA/calls" || false
  [ -z "$(git status --porcelain)" ]
}
