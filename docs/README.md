# DeskFlow – dokumentacja

DeskFlow to mały projekt typu proof of concept (PoC). Sprawdza, jak wersjonować kod bazy Oracle (tabele, PL/SQL) i aplikację Oracle APEX w Gicie i jak bezpiecznie przenosić zmiany między środowiskami DEV i TEST.

Projekt powstał z prawdziwego problemu zespołu. Czterech programistów pracuje na jednej wspólnej bazie DEV i edytuje pakiety bezpośrednio w bazie. Przez to zdarza się, że ktoś nadpisze cudzą zmianę i nie wiadomo, co zniknęło. Na TEST i PROD zmiany trafiają ręcznie puszczanymi skryptami i eksportem aplikacji APEX. W firmie działa Oracle 19c i APEX 24.2.8.

Projekt porównuje trzy podejścia: **Liquibase**, **SQLcl Projects** (narzędzie Oracle oparte na Liquibase) oraz **Git z numerowanymi skryptami**, ewentualnie z narzędziem Flyway. Wynikiem ma być konkretna rekomendacja: czy Liquibase się sprawdza, a jeśli nie, to co w zamian.

## Spis treści

| Plik | Zawartość |
|---|---|
| [00-plan-i-kryteria.md](00-plan-i-kryteria.md) | Zakres aplikacji, scenariusze testowe, kryteria oceny, plany awaryjne |
| [01-srodowisko.md](01-srodowisko.md) | Dziennik instalacji lokalnego środowiska, krok po kroku z punktami kontrolnymi |
| [02-problemy-i-rozwiazania.md](02-problemy-i-rozwiazania.md) | Problemy napotkane po drodze i sposób ich rozwiązania |
| [03-slownik.md](03-slownik.md) | Krótkie wyjaśnienia pojęć (CDB/PDB, SYS/SYSTEM, SQLcl, ORDS, Liquibase…) |
| [04-wdrozenie-w-istniejacym-srodowisku.md](04-wdrozenie-w-istniejacym-srodowisku.md) | Jak wprowadzić wersjonowanie, gdy DEV/TEST/PROD już istnieją: porównanie, baseline, synchronizacja, kolejność wdrażania w zespole |

## Status

| Etap | Stan |
|---|---|
| Plan i kryteria oceny | ✅ ustalone |
| Środowisko: narzędzia (SQLcl, ORDS, Java) | ✅ gotowe |
| Środowisko: baza (PDB `DESKFLOW`), APEX 24.2.0, ORDS 26.3.1, workspace'y DEV/TEST, połączenia SQL Developera, Git for Windows 2.56.1 | ✅ gotowe |
| Środowisko: Liquibase 5.0.4 (`Path`, sterownik Oracle), inicjalizacja repozytorium | 🔄 w trakcie |
| Aplikacja DeskFlow (DEV) | ⏳ później |
| Wersjonowanie i scenariusze testowe | ⏳ później |
| Raport porównawczy i rekomendacja | ⏳ później |
