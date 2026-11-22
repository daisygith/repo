# Wdrożenie w istniejącym środowisku (brownfield)

Ten rozdział opisuje, jak wprowadzić wersjonowanie bazy, gdy środowiska DEV, TEST i PROD **już istnieją i działają**. Tak jest w zespole, dla którego powstaje ten projekt:

- 4 programistów pracuje na jednej, wspólnej bazie DEV;
- na TEST i PROD zmiany trafiają ręcznie puszczanymi skryptami;
- aplikacja APEX jest eksportowana i importowana między środowiskami;
- Oracle 19c, APEX 24.2.8.

**Oznaczenia:**
- 🔬 **do sprawdzenia w PoC**: zaplanowane, jeszcze nieprzetestowane;
- ✅ **sprawdzone w PoC**: przetestowane w laboratorium, z wynikiem.

Na tym etapie projektu wszystkie punkty mają status 🔬. Wyniki będą dopisywane po kolejnych etapach (Liquibase, SQLcl Projects, scenariusze testowe).

---

## 1. Dlaczego to osobny przypadek

Liquibase, SQLcl Projects i Flyway zakładają, że **znają historię zmian bazy**: każda zmiana jest changesetem, a tabela `DATABASECHANGELOG` mówi, które changesety już wykonano.

Istniejące bazy tej historii nie mają. Są tylko efektem lat ręcznych zmian. Gdyby uruchomić na nich changelog „od zera”, narzędzie próbowałoby utworzyć obiekty, które już istnieją, i skończyłoby się błędami albo, co gorsze, nadpisaniem.

Dlatego najpierw trzeba:
1. dowiedzieć się, co faktycznie jest w każdej bazie;
2. uzgodnić jeden stan wzorcowy;
3. zapisać go jako punkt startowy (**baseline**);
4. powiedzieć narzędziu, że istniejące bazy już ten stan mają.

Dopiero od tego momentu kolejne zmiany idą normalną ścieżką przez narzędzie.

---

## 2. Inwentaryzacja i porównanie środowisk 🔬

W praktyce prawie zawsze **DEV ≠ TEST ≠ PROD**. Przyczyny to poprawki robione bezpośrednio na PROD, nieskończone zmiany na DEV i zapomniane skrypty.

**Sposoby porównania:**

| Narzędzie | Jak | Uwagi |
|---|---|---|
| SQL Developer **Database Diff** | Tools → Database Diff, dwa połączenia | graficzne, szybkie na początek; wynik trudny do zapisania w repo |
| `liquibase diff` | porównanie dwóch połączeń | raport tekstowy różnic; zakres obsługiwanych typów obiektów do sprawdzenia |
| Eksport do plików + `git diff` | SQLcl `project export` albo `lb generate-schema -split` z każdego środowiska do osobnych katalogów lub gałęzi, potem `git diff` | najbardziej czytelne; ten sam format plików dla wszystkich środowisk |

**Wynik:** lista różnic do wyjaśnienia (obiekt, środowisko, rodzaj różnicy), np.:

| Obiekt | DEV | TEST | PROD | Do wyjaśnienia |
|---|---|---|---|---|
| `PKG_X` | wersja nowsza | = PROD | wzorzec | niewydana zmiana na DEV? |
| `TAB_Y.KOL_Z` | jest | brak | brak | porzucony pomysł czy niewdrożona zmiana? |
| indeks `IDX_Q` | brak | brak | jest | poprawka wydajności zrobiona tylko na PROD? |

---

## 3. Wybór wzorca i uzgodnienie różnic 🔬

**Wzorcem jest zwykle PROD**, bo to on reprezentuje stan, który faktycznie działa u użytkowników.

Dla każdej różnicy podejmuje się decyzję:

| Decyzja | Kiedy |
|---|---|
| **Wdrożyć brakujące** | zmiana jest potrzebna, a środowisko ją pominęło |
| **Usunąć zbędne** | pozostałość po porzuconej pracy, nikt jej nie używa |
| **Zostawić świadomie** | różnica jest celowa (np. konfiguracja środowiska). Zapisać ją jako wyjątek |

Decyzje warto zapisać, np. jako tabelę w repo albo listę zgłoszeń. Później będzie wiadomo, dlaczego środowiska wyglądają tak, a nie inaczej.

---

## 4. Baseline: wersja startowa w repozytorium 🔬

Po uzgodnieniu różnic stan wzorca trafia do repozytorium jako **wersja startowa**:

| Podejście | Polecenie |
|---|---|
| Liquibase | `liquibase generate-changelog` (z połączeniem do wzorca) |
| SQLcl Projects | `project export` |
| SQLcl Liquibase | `lb generate-schema -split` |

Następnie:
- przejrzeć wygenerowane pliki, bo narzędzia potrafią pominąć niektóre typy obiektów albo wygenerować je w niewygodnej formie;
- zrobić commit i oznaczyć go tagiem, np. **`v1.0-baseline`**.

Do sprawdzenia w PoC: jakie typy obiektów każde narzędzie eksportuje poprawnie, a jakie trzeba uzupełnić ręcznie.

---

## 5. Oznaczenie istniejących baz jako „mających baseline” 🔬

Istniejące bazy **już mają** obiekty z baseline. Nie wolno ich tworzyć ponownie. Trzeba tylko zapisać w bazie, że changesety baseline są „wykonane”.

| Podejście | Jak |
|---|---|
| Liquibase | **`liquibase changelog-sync`**: wypełnia `DATABASECHANGELOG` wpisami dla wszystkich changesetów, **bez ich uruchamiania** |
| SQLcl Projects | odpowiednik do ustalenia w PoC |

> ⚠️ **Ostrzeżenie:** `changelog-sync` na bazie, która **nie jest** zgodna z baseline, **ukrywa różnice**. Narzędzie uzna, że wszystko jest w porządku, choć baza wygląda inaczej. Dlatego kroki 2 i 3 (porównanie i uzgodnienie) muszą być zrobione **przed** `changelog-sync`, a po nim warto jeszcze raz porównać bazę z repozytorium.

---

## 6. APEX w istniejących środowiskach 🔬

- **Eksport z wzorca:** aplikacja eksportowana w formie podzielonej (`-split`) z czytelnym YAML (`READABLE_YAML`) do repozytorium. Jeden plik na stronę i komponent pozwala zobaczyć różnice w Gicie.
- **Różne ID aplikacji i workspace'y:** w firmie aplikacja może mieć inne ID i inny workspace na DEV, TEST i PROD. Import musi to uwzględniać:
  - `apex_application_install` (ustawienie workspace, ID aplikacji, offsetu ID komponentów, schematu) przed uruchomieniem skryptu instalacyjnego,
  - albo odpowiednie opcje importu w SQLcl.
- **Wersje APEX** muszą być zgodne między środowiskami. Eksportu z nowszego patch setu nie da się zaimportować do starszego.

Do sprawdzenia w PoC: który sposób importu z nadpisaniem ID i workspace działa najprościej i czy da się go włączyć do changelogu (scenariusz 6).

---

## 7. Rzeczy łatwe do przeoczenia 🔬

| Element | Na co uważać |
|---|---|
| **Granty** | uprawnienia między schematami i dla ról; często nadawane ręcznie i nigdzie niezapisane |
| **Synonimy** | publiczne i prywatne, wskazujące na inne schematy |
| **Database linki** | różne cele w każdym środowisku, z hasłami. Hasła nie mogą trafić do repo |
| **Joby `DBMS_SCHEDULER`** | harmonogramy, programy, argumenty; mogą być celowo wyłączone na DEV |
| **Sekwencje** | bieżące wartości różnią się między środowiskami i **nie należy ich wersjonować**. Wersjonuje się definicję, a nie wartość |
| **Obiekty w innych schematach** | zależności od schematów spoza projektu |
| **Dane** | w changelogach tylko **dane słownikowe** (statusy, kategorie), nigdy dane biznesowe |
| **Konfiguracja zależna od środowiska** | parametry, adresy URL, ścieżki: poza kodem, np. w tabeli konfiguracyjnej wypełnianej osobno na każdym środowisku |

---

## 8. Zasady od dnia startu 🔬

1. **Żadnych ręcznych zmian poza procesem.** Każda zmiana schematu przechodzi przez repozytorium i narzędzie.
2. **Kontrola dryfu.** Okresowo, np. przed każdym wydaniem, porównywać bazę z repozytorium. Każda różnica to sygnał, że ktoś ominął proces.
3. **Wyzwalacz DDL jako siatka bezpieczeństwa.** Zapisuje, kto, kiedy i co zmienił, wraz z poprzednią wersją kodu (zob. [00-plan-i-kryteria.md](00-plan-i-kryteria.md)).
4. **Dostęp do PROD.** Tylko osoba odpowiedzialna za wydania albo automat. Programiści nie mają praw do zmian schematu na PROD.

---

## 9. Proponowana kolejność wprowadzania w zespole 🔬

Etapami, żeby nie zatrzymać bieżącej pracy:

| Etap | Co | Efekt |
|---|---|---|
| **a** | Wyzwalacz DDL na DEV + kod pakietów w Gicie | od razu widać, kto co nadpisał; kod ma historię |
| **b** | Pull Requesty i akceptacja szefa | zmiany są przeglądane przed scaleniem |
| **c** | Baseline + `changelog-sync` na TEST; wdrożenia na TEST przez narzędzie | koniec ręcznych skryptów na TEST |
| **d** | To samo na PROD | powtarzalne, udokumentowane wydania |
| **e** | (opcjonalnie) osobne schematy deweloperskie zamiast wspólnego DEV | koniec nadpisywania się nawzajem u źródła |

Każdy etap daje korzyść sam w sobie, więc można zatrzymać się na dowolnym.

---

## 10. Checklista przed pierwszym wdrożeniem narzędziem na PROD 🔬

- [ ] Aktualna **kopia zapasowa** PROD, z potwierdzoną możliwością odtworzenia.
- [ ] **Próba na kopii PROD:** całe wdrożenie wykonane najpierw na świeżej kopii produkcji.
- [ ] **Plan wycofania:** wiadomo, co zrobić, gdy wdrożenie się nie uda (rollback, naprawa kolejną zmianą, odtworzenie z kopii).
- [ ] `DATABASECHANGELOG` na PROD wypełniony przez `changelog-sync` **po** potwierdzeniu zgodności z baseline.
- [ ] Wersje APEX zgodne między środowiskiem źródłowym a PROD.
- [ ] Konfiguracja zależna od środowiska (db linki, URL-e, parametry) poza wdrażanym kodem.
- [ ] **Porównanie po wdrożeniu:** PROD zgodny z repozytorium, bez nieoczekiwanych różnic.
- [ ] Okno serwisowe i osoby kontaktowe ustalone.

---

## Wnioski z PoC dla istniejących DEV/TEST/PROD

Sekcja uzupełniana po kolejnych etapach projektu (Liquibase, SQLcl Projects, scenariusze 1–7).

| Etap | Wniosek | Status |
|---|---|---|
| Instalacja Liquibase | W firmowej sieci z inspekcją TLS (proxy, antywirus) pobieranie przez Liquibase LPM i inne narzędzia Javowe skończy się błędem `PKIX path building failed`, bo Java ma własny magazyn certyfikatów. Trzeba zaplanować **lokalne repozytorium artefaktów** (np. firmowy mirror) albo **dołączanie sterownika JDBC ręcznie** (np. `ojdbc11.jar` z SQLcl), uzgodnione z działem bezpieczeństwa. W PoC zadziałało ręczne dołączenie sterownika. | ✅ |
| Repozytorium | Przy dodawaniu istniejącego kodu do repo dodawać pliki po nazwach (nie `git add .`), mieć `.gitignore` z `liquibase.properties` i plikami z hasłami, oraz od razu ustalić końce linii (`.gitattributes`), żeby sumy kontrolne Liquibase były takie same na komputerach wszystkich programistów. | 🔬 |
| Model v1.0 | Pakiety w plikach `.pks`/`.pkb`, typowe w firmach, nie są rozpoznawane przez Liquibase jako formatted SQL. Trzeba zmienić nazwy na `.sql` albo dołączać je przez `<sqlFile>` (do sprawdzenia). Ograniczenia z nazwami systemowymi `SYS_Cnnnn` na istniejących bazach dadzą fałszywe różnice przy porównaniach, więc przy inwentaryzacji warto zaplanować nadanie im jawnych nazw. | ✅ rozszerzenia / 🔬 `<sqlFile>` |
| Konteksty | Dane demo i testowe oznaczać kontekstem i na TEST/PROD zawsze wykluczać (`--contexts=!demo`), najlepiej na stałe w pliku właściwości środowiska. | ✅ |
| Wdrożenie v1.0 na DEV | Przed każdym wdrożeniem uruchamiać `liquibase status` (niczego nie zmienia, pokazuje, co pójdzie). Po wdrożeniu kodu PL/SQL zawsze sprawdzać `user_objects` i `user_errors`, bo Liquibase nie zgłasza pakietów skompilowanych z błędami. Na istniejących bazach z wieloma pakietami to szczególnie ważne. | ✅ |
