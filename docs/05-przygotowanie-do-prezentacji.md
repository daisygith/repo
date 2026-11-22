# Przygotowanie do prezentacji

Materiał do przedstawienia projektu przełożonemu: krótka ściąga, przebieg pokazu, pytania z odpowiedziami i proste wyjaśnienia pojęć.

Powtórka materiału z pytaniami kontrolnymi: [06-lekcje.md](06-lekcje.md).

**Oznaczenia:**
- ✅ istnieje / sprawdzone w PoC
- 🔄 w trakcie
- ⏳ jeszcze nie istnieje
- 🔬 do sprawdzenia w PoC: nie przedstawiać jako pewnika

---

## a) Ściąga w 5 zdaniach

1. Dziś kod bazy (pakiety, tabele) i aplikacja APEX nie mają historii zmian: pracujemy na wspólnej bazie DEV, więc zdarza się, że ktoś nadpisze cudzą zmianę i nie wiadomo, co zniknęło.
2. Zbudowałam małą aplikację testową DeskFlow (zgłoszenia service desku), żeby sprawdzić rozwiązanie na bezpiecznym przykładzie, a nie na naszym systemie.
3. Kod bazy jest w Gicie jako zwykłe pliki, a narzędzie (Liquibase albo SQLcl Projects) wdraża zmiany na kolejne środowiska samo, po kolei, i zapamiętuje w bazie, co już wdrożyło.
4. Dzięki temu każda zmiana ma autora, datę i opis, przed wdrożeniem można ją przejrzeć, a TEST i PROD dostają dokładnie to, co jest w repozytorium, bez ręcznego składania skryptów.
5. Porównuję trzy podejścia (Liquibase, SQLcl Projects, Git z prostymi skryptami) według tych samych kryteriów i na końcu dam konkretną rekomendację, także dla naszych istniejących baz.

---

## b) Przebieg prezentacji krok po kroku

| # | Co pokazać na ekranie | Co powiedzieć | Stan |
|---|---|---|---|
| 1 | Problem: tabela „jak jest dziś” z [00-plan-i-kryteria.md](00-plan-i-kryteria.md) | „To jest nasz punkt wyjścia: wspólny DEV, ręczne skrypty, brak historii.” | ✅ |
| 2 | Repozytorium w GitHub Desktop lub VS Code: katalogi `db/tables`, `db/packages`, `db/data` | „Cały kod bazy jest w plikach. Każdy plik ma historię.” | 🔄 (gałąź `feature/model-v1.0`) |
| 3 | `db/changelog-master.xml` i jeden plik tabeli z `--changeset` i `--rollback` | „To jest spis zmian. Narzędzie wykonuje je po kolei i wie, które już poszły.” | 🔄 |
| 4 | Podgląd SQL bez bazy (`liquibase update-sql`, tryb offline) | „Zanim cokolwiek wdrożę, widzę dokładnie, jaki SQL się wykona.” | ✅ sprawdzone |
| 5 | `liquibase status`, potem wdrożenie na DEV (`liquibase update`), tabela `DATABASECHANGELOG` w SQL Developerze i `user_errors` | „Najpierw widzę, co pójdzie, potem narzędzie wdraża i zapisuje w bazie, co i kiedy. Na koniec sprawdzam, czy cały kod się skompilował.” | ✅ |
| 6 | Aplikacja APEX na DEV | „Aplikacja działa na tym, co przyszło z repozytorium.” | ⏳ |
| 7 | Pull Request: zmiana pakietu na osobnej gałęzi, widok różnic | „Zmiana jest przeglądana przed scaleniem. Konflikt dwóch osób widać od razu, zamiast cichego nadpisania.” | ⏳ (scenariusz 3) |
| 8 | Wdrożenie na TEST jednym poleceniem, z `--contexts=!demo` | „TEST dostaje dokładnie to, co w repozytorium, bez danych demo.” | ⏳ (scenariusz 1) |
| 9 | Wykrycie zmiany zrobionej bezpośrednio w bazie (drift) | „Jeśli ktoś ominie proces, wykryjemy to.” | ⏳ (scenariusz 4) |
| 10 | Tabela porównania narzędzi i rekomendacja | „Tak wypadły trzy podejścia, to proponuję.” | ⏳ |
| 11 | Plan wprowadzenia u nas: etapy a–e z [04-wdrozenie-w-istniejacym-srodowisku.md](04-wdrozenie-w-istniejacym-srodowisku.md) | „Można zacząć od małego kroku, bez zatrzymywania pracy.” | ✅ plan / 🔬 wykonanie |

**Wskazówka:** prezentację najlepiej przećwiczyć na żywym środowisku. Kroki oznaczone ⏳ zaktualizujemy po wykonaniu scenariuszy.

---

## c) Pytania, które może zadać szef

| Pytanie | Krótka odpowiedź | Stan |
|---|---|---|
| **Co, jeśli ktoś zmieni pakiet bezpośrednio w bazie?** | Narzędzie samo tego nie zablokuje. Wykryjemy to porównaniem bazy z repozytorium (drift), a wyzwalacz DDL zapisze, kto, kiedy i co zmienił, razem z poprzednią wersją kodu. Docelowo na TEST i PROD zmiany może wprowadzać tylko narzędzie. | 🔬 (scenariusz 4, wyzwalacz DDL) |
| **Czy to działa z 19c?** | Liquibase obsługuje Oracle 19c, a kod piszemy zgodnie z 19c. Laboratorium działa na 21c, czyli bliżej 19c niż najnowsza wersja. Dla SQLcl Projects nie znalazłam oficjalnej informacji o 19c. Trzeba to sprawdzić osobno, najlepiej na kopii u nas. | ✅ Liquibase / 🔬 SQLcl Projects na 19c |
| **Ile to kosztuje?** | Liquibase Community, SQLcl i Git są darmowe. Kosztem jest czas na wdrożenie i przyzwyczajenie zespołu. Płatne są np. Liquibase Pro/Secure czy Docker Desktop w firmie, ale nie są potrzebne. | ✅ |
| **Co z naszymi istniejącymi bazami?** | Najpierw porównujemy DEV, TEST i PROD, uzgadniamy różnice i zapisujemy stan wzorca (zwykle PROD) jako wersję startową. Potem oznaczamy istniejące bazy jako „mające tę wersję”, bez ponownego wykonywania skryptów (`changelog-sync`). Opis w rozdziale 04. | 🔬 (scenariusz 7) |
| **Jak cofnąć wdrożenie?** | Każda zmiana tabeli ma zapisany sposób wycofania (`--rollback`), a Liquibase potrafi je wykonać. Przy pakietach zwykle wdraża się po prostu poprzednią wersję z Gita. Na PROD i tak obowiązuje kopia zapasowa przed wdrożeniem. | 🔬 (scenariusz 5) |
| **Czemu nie po prostu skrypty, jak dziś?** | Skrypty nie pamiętają, co już wykonano na którym środowisku, i łatwo jakiś pominąć. Narzędzie prowadzi ten rejestr samo, a Git daje historię i przegląd zmian. Uporządkowane skrypty to nasz Plan C, jeśli narzędzia się nie sprawdzą. | ✅ zasada / ⏳ porównanie |
| **Co z aplikacją APEX?** | Eksportujemy ją do repozytorium w podziale na strony, w czytelnym formacie. W Gicie widać wtedy, co zmieniło się na której stronie. Import na TEST z innym ID i workspace'em będzie sprawdzony. | 🔬 (scenariusz 6) |
| **Ile to zajmie programistom na co dzień?** | To jedno z kryteriów oceny: dodatkowa praca przy jednej zmianie ma trwać minuty, a nie pół godziny. Wynik będzie w raporcie. | ⏳ |
| **Czy dane trafią przez to na TEST/PROD?** | Tylko dane słownikowe (np. kategorie). Dane demo są oznaczone i na TEST wykluczone (`--contexts=!demo`). | ✅ sprawdzone offline |
| **Co, jeśli dwie osoby zmienią ten sam pakiet?** | Każdy pracuje na swojej gałęzi w Gicie, a przy scalaniu Git pokaże konflikt i trzeba go świadomie rozwiązać, zamiast cicho nadpisać. | 🔬 (scenariusz 3) |
| **Czy to bezpieczne (hasła)?** | Hasła są poza repozytorium. W repo jest tylko wzór pliku konfiguracyjnego bez haseł. | ✅ |

**Zasada:** na pytanie o rzecz oznaczoną 🔬 lepiej odpowiedzieć „to sprawdzam w scenariuszu X” niż obiecywać wynik.

---

## d) Powiedz to prostymi słowami

| Pojęcie | Prościej |
|---|---|
| **Git / repozytorium** | Archiwum plików, które pamięta każdą wersję: kto, kiedy i co zmienił. |
| **Commit** | Zapisanie paczki zmian w historii, z opisem. |
| **Gałąź (branch)** | Osobna kopia robocza, na której można pracować, nie przeszkadzając innym. |
| **Pull Request** | Prośba „przejrzyj i dołącz moją zmianę”. Ktoś ją ogląda, zanim trafi do wspólnej wersji. |
| **Liquibase** | Program, który wykonuje zmiany w bazie po kolei i pamięta, które już wykonał. |
| **Changelog** | Spis wszystkich zmian bazy w ustalonej kolejności. |
| **Changeset** | Jedna zmiana z tego spisu, np. „dodaj kolumnę”. |
| **`DATABASECHANGELOG`** | Tabela w bazie, w której Liquibase odhacza wykonane zmiany. |
| **Rollback** | Cofnięcie zmiany. |
| **Kontekst (`demo`)** | Etykieta na zmianie, np. „tylko dane demonstracyjne”, żeby nie trafiły na TEST. |
| **Drift** | Baza „rozjechała się” z repozytorium, bo ktoś zmienił coś ręcznie. |
| **Baseline** | Zdjęcie stanu istniejącej bazy, od którego zaczynamy wersjonowanie. |
| **SQLcl Projects** | Narzędzie Oracle, które samo robi część pracy Liquibase: eksportuje obiekty i aplikację APEX i przygotowuje zmiany. |
| **Wyzwalacz DDL** | „Kamera” w bazie, która notuje każdą zmianę kodu razem z poprzednią wersją. |
