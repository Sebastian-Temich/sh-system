
## Lovable

Projekt powstał w Lovable, a synchronizacja Lovable z GitHubem zostaje włączona: zmiany z Lovable
przychodzą na `main` jako commity, a nasze PR wracają do Lovable.

- Nie publikujesz w Lovable (Publish, Share, własna domena) bez decyzji właściciela w `docs/decyzje.md`.
- Nie wyłączasz synchronizacji z GitHubem i nie zmieniasz ustawień projektu w Lovable.
- Commit z Lovable na `main` w trakcie zadania to zwykła zmiana `main`: aktualizujesz gałąź zadania
  przez `gh pr update-branch`, nie cofasz go.
- Klucz `anon` w `src/integrations/supabase/client.ts` jest publiczny z założenia; klucz
  `service_role` nigdy nie trafia do kodu frontendu ani repo.
