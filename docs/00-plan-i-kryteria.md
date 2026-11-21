# Plan projektu i kryteria oceny

## Punkt wyjścia: jak jest dziś

| Obszar | Obecna praktyka | Problem |
|---|---|---|
| Kod PL/SQL | edytowany bezpośrednio w bazie DEV (SQL Developer) | brak historii zmian; kto ostatni skompilował, ten „wygrywa” |
| Zespół | 4 programistów na jednej bazie DEV | nadpisywanie cudzych zmian, nie wiadomo, co zniknęło |
| Wdrożenia TEST/PROD | skrypty puszczane ręcznie | łatwo coś pominąć, brak śladu, co jest wdrożone |
| Aplikacja APEX | eksport „dobrej” wersji i import na kolejne środowisko | eksport to jeden duży plik, trudno zobaczyć różnice |

Środowisko firmowe: **Oracle 19c**, **APEX 24.2.8**. Zespół rozważa przejście z SQL Developera na VS Code. Oracle ma rozszerzenie „SQL Developer for VS Code” z wbudowanym SQLcl.

## Pytanie, na które odpowiada projekt

1. Czy Liquibase nadaje się do wersjonowania i wdrażania kodu Oracle (PL/SQL) i aplikacji APEX?
2. Jeśli nie, czym go zastąpić?
3. Jak to wszystko działa w praktyce, od edycji kodu do wdrożenia na TEST?

## Zakres aplikacji DeskFlow

Celowo mała aplikacja typu service desk (zgłoszenia), do zbudowania w 1–2 weekendy. Ma wystarczyć do pokazania scenariuszy, a nie być pełnym produktem.

- **4 tabele:** zgłoszenia, kategorie, użytkownicy/agenci, komentarze
- **1–2 pakiety PL/SQL:** utworzenie zgłoszenia, zmiana statusu, przypisanie do agenta
- **4–5 stron APEX:** lista zgłoszeń, formularz, szczegóły z komentarzami, prosty dashboard

**Zasada:** kod piszemy zgodnie z **Oracle 19c**, czyli bez nowości z 23ai, np. bez typu `BOOLEAN` w kolumnach i bez `IF NOT EXISTS`. Dzięki temu wynik przełoży się na środowisko firmowe.

## Środowiska

| Środowisko | Schemat | Workspace APEX | Rola |
|---|---|---|---|
| DEV | `DESK_A_DEV` | `DESK_A_DEV` | budowa i rozwój aplikacji |
| TEST | `DESK_A_TEST` | `DESK_A_TEST` | odtwarzanie i sprawdzanie wydań |

Oba schematy są w jednej bazie lokalnej, w osobnej PDB `DESKFLOW`. To izolacja logiczna, wystarczająca do nauki i testów, a nie rozdzielenie infrastruktury jak w firmie.

## Scenariusze testowe

| # | Scenariusz | Co pokazuje |
|---|---|---|
| 1 | **Start od zera:** cała aplikacja (tabele, pakiety, APEX) na pustym TEST jednym poleceniem | czy repozytorium jest kompletnym źródłem prawdy |
| 2 | **Wydanie 1.1:** nowa kolumna + zmiana pakietu + nowa strona APEX, wdrożone na TEST | typowy cykl wydania bez ręcznego składania skryptów |
| 3 | **Dwóch programistów, jeden pakiet:** dwie gałęzie w Gicie zmieniają ten sam pakiet | wykrycie konfliktu zamiast cichego nadpisania |
| 4 | **Zmiana bezpośrednio w bazie:** ktoś zmienia pakiet z pominięciem Gita | wykrycie rozjazdu baza ↔ Git (tzw. drift) |
| 5 | **Błędne wdrożenie:** wycofanie albo naprawa kolejną zmianą | co robić, gdy coś pójdzie źle |
| 6 | **Inne ID aplikacji i workspace na TEST** | poprawny import APEX mimo różnic między środowiskami |
| 7 | **Istniejące środowiska (brownfield):** przed włączeniem narzędzia ręcznie tworzymy te same obiekty na DEV i TEST, z celowymi drobnymi różnicami. Potem porównanie, uzgodnienie, baseline i synchronizacja (`changelog-sync` lub odpowiednik) | jak wprowadzić narzędzie w działających środowiskach, takich jak w firmie |

Scenariusze 3 i 4 odpowiadają bezpośrednio problemowi zespołu z nadpisywaniem kodu. Scenariusz 7 odpowiada sytuacji startowej firmy, w której DEV, TEST i PROD już istnieją. Szczegóły w [04-wdrozenie-w-istniejacym-srodowisku.md](04-wdrozenie-w-istniejacym-srodowisku.md).

## Kryteria oceny

Liquibase „wypala”, jeśli w scenariuszach spełnia:

1. **Odtworzenie od zera:** pusty schemat TEST dostaje całą aplikację jednym poleceniem, bez ręcznych poprawek.
2. **Pakiety PL/SQL:** zmiana w pliku pakietu sama trafia na TEST przy kolejnym wdrożeniu (np. `runOnChange:true`), bez pisania nowego changesetu za każdym razem.
3. **APEX:** aplikacja instaluje się na TEST mimo innego workspace i ID aplikacji.
4. **Historia:** po wdrożeniu da się odpowiedzieć, co jest na TEST i z którego commita.
5. **Koszt w codziennej pracy:** dodatkowa praca programisty przy jednej zmianie to minuty, a nie pół godziny.

Jeśli punkty 1–4 działają, a punkt 5 wypada źle, wniosek brzmi: działa, ale jest za drogie w codziennej pracy. To też jest wartościowa odpowiedź.

## Porównywane podejścia

| Podejście | Na czym polega |
|---|---|
| **A. Liquibase Community** | changesety pisane ręcznie (SQL lub XML); Liquibase pamięta w tabeli `DATABASECHANGELOG`, co już wdrożono |
| **B. SQLcl Projects** | narzędzie Oracle oparte na Liquibase (`project init / export / stage / release / deploy`); samo eksportuje obiekty i aplikacje APEX i generuje changesety z różnic w Gicie |
| **C. Git + numerowane skrypty** (opcjonalnie Flyway) | zmiany tabel jako pliki z numerem (`V012__dodaj_priorytet.sql`), pakiety i widoki jako pliki `create or replace` wgrywane w całości, mała tabela w bazie zapamiętuje wykonane skrypty |
| **Punkt odniesienia** | obecna praktyka zespołu: co zyskujemy względem dziś |

### Plan B: SQLcl Projects

Jeśli czysty Liquibase odpadnie z powodu kryterium 5 (za dużo ręcznej pracy), SQLcl Projects ma duże szanse to rozwiązać, bo automatyzuje właśnie tę część. Jeśli odpadnie z innego powodu, np. przez sposób działania APEX, przechodzimy do Planu C.

### Plan C: Git + numerowane skrypty / Flyway

Najprostsze podejście, najbliższe obecnej praktyce zespołu, tylko uporządkowane i z historią w Gicie.

## Siatka bezpieczeństwa: wyzwalacz DDL

Niezależnie od wybranego narzędzia, problem „ktoś nadpisał i nie wiadomo, co zniknęło” można złagodzić od razu **wyzwalaczem DDL na poziomie schematu**. Przed każdym `CREATE OR REPLACE` zapisuje on do tabeli audytowej:

- kto zmienił obiekt (użytkownik bazy, użytkownik systemu operacyjnego),
- kiedy i z jakiego komputera,
- **poprzednią wersję kodu** z `USER_SOURCE`.

To ok. 30 linii PL/SQL i działa na 19c. Nie zastępuje Gita, ale od pierwszego dnia pozwala odzyskać nadpisany kod. Da się to wdrożyć w firmie szybko, zanim zmieni się cały proces. W projekcie to osobny scenariusz.

## Otwarte pytania

| Pytanie | Stan |
|---|---|
| Czy SQLcl Projects obsługuje Oracle **19c**? | **Niepotwierdzone.** W oficjalnej dokumentacji i notach wydania nie znaleziono jasnej informacji o minimalnej wersji bazy. Trzeba to sprawdzić samodzielnie, najlepiej na osobnym schemacie w środowisku firmowym 19c, gdy laboratorium pokaże, co warto testować. |
| Różnica wersji APEX: lab **24.2.0**, firma **24.2.8** | Patch set 24.2.8 jest dostępny tylko przez Oracle Support. Dla PoC bez znaczenia, ale eksportu z 24.2.8 nie zaimportuje się do 24.2.0, więc **nie przenosimy firmowej aplikacji do laboratorium**. Aplikacja DeskFlow powstaje od zera w labie. |
| Czy w firmie wolno używać SQLcl / Dockera? | SQLcl jest darmowy (Oracle). Docker Desktop ma osobne warunki licencji dla firm; w laboratorium Docker okazał się niepotrzebny (zob. [01-srodowisko.md](01-srodowisko.md)). |

## Kolejność prac

1. Środowisko lokalne ([01-srodowisko.md](01-srodowisko.md)).
2. Pierwsza wersja aplikacji DeskFlow na DEV.
3. Wersjonowanie: najpierw SQLcl Projects, potem dla porównania czysty Liquibase.
4. Scenariusze 1–7 i raport porównawczy z rekomendacją, z wnioskami dla istniejących środowisk DEV/TEST/PROD.
5. Publikacja repozytorium na GitHubie z opisem całego procesu.

## Źródła

- [SQLcl Changelog (Oracle)](https://www.oracle.com/tools/sqlcl/sqlcl-changelog.html)
- [SQLcl Release Notes 25.3](https://www.oracle.com/tools/sqlcl/sqlcl-relnotes-25.3.0.html)
- [SQLcl User's Guide – Projects, wprowadzenie](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/25.3/sqcug/introduction.html)
- [Jeff Smith: SQLcl Projects](https://www.thatjeffsmith.com/archive/2025/05/sqlcl-projects-automated-oracle-database-app-deployments/)
- [Pretius: SQLcl Project command](https://pretius.com/blog/oracle-sqlcl-project-command)
- [Oracle-base: wdrażanie APEX przez SQLcl i Liquibase](https://Oracle-base.com/articles/misc/sqlcl-deploying-oracle-application-express-apex-applications-using-sqlcl-and-liquibase)
