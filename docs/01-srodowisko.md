# Środowisko lokalne – dziennik instalacji

Ten dokument opisuje instalację **tak, jak faktycznie przebiegała**, z decyzjami i punktami kontrolnymi. Bazowy plan pochodził z osobnej instrukcji (Docker + Oracle Database Free 23ai). W trakcie zmieniliśmy go po sprawdzeniu, co już jest zainstalowane na komputerze.

> Hasła nigdy nie trafiają do tego repozytorium. Wszędzie, gdzie jest mowa o haśle, wpisuje się je wyłącznie lokalnie.

## Sprzęt i stan wyjściowy

| Element | Stan |
|---|---|
| System | Windows 11 Pro x64 |
| Procesor / RAM | Intel Core i7 (8. gen.) / 16 GB |
| Wirtualizacja w BIOS | włączona |
| Wolne miejsce | C: ~100 GB, D: ~275 GB |
| Oracle Database **XE 21c** | zainstalowana wcześniej na dysku D:, działa jako usługa Windows, nasłuch na porcie 1521 |
| Pliki instalacyjne APEX 24.2 | rozpakowane wcześniej w `C:\apex\apex`, ale **APEX nie był zainstalowany w bazie** |
| JDK | 21 i 25 (domyślnie w `Path` uruchamiała się Java 25) |
| SQL Developer | zainstalowany |
| VS Code | zainstalowany |
| Git | dostępny przez GitHub Desktop (nie ma go w `Path`) |
| WSL2, Docker | brak |

## Decyzja: XE 21c zamiast Docker + Oracle Free 23ai

Pierwotna instrukcja zakładała Docker Desktop z WSL2 i kontener z Oracle Database Free (23ai). Ponieważ na komputerze działa już Oracle XE 21c, wybraliśmy go.

**Dlaczego:**
- **21c jest bliżej firmowego 19c** niż 23ai, więc wnioski lepiej przełożą się na firmę.
- Odpada instalacja WSL2 i Dockera, czyli najbardziej ryzykowna część całego środowiska.
- Ograniczenia XE (ok. 2 GB pamięci dla bazy, 12 GB danych użytkownika) w zupełności wystarczają do małej aplikacji.
- Izolacja: osobna PDB `DESKFLOW` nie miesza się z tym, co już jest w bazie (np. w `XEPDB1`).

**Wady (świadomie zaakceptowane):**
- XE 21c nie dostaje już poprawek.
- Środowiska nie da się odtworzyć jednym poleceniem, jak kontenera Docker.

Pliki bazy XE leżą na D: (`<ORACLE_BASE>\oradata\XE\...`), więc dysk C: obciążają tylko narzędzia (poniżej 1 GB).

## Krok 1: Struktura katalogów ✅

```
C:\deskflow
├── tools     narzędzia (SQLcl, ORDS, później Liquibase)
├── config    konfiguracja ORDS (poza programem ORDS)
├── secrets   lokalne hasła – nigdy w repozytorium
├── logs      logi instalacji
├── backups   kopie zapasowe
└── repo      repozytorium Git – tylko ten katalog trafia na GitHuba
```

Pliki APEX zostają w dotychczasowym miejscu: `C:\apex\apex`.

**Punkt kontrolny:** wszystkie podkatalogi istnieją. ✅

## Krok 2: SQLcl i ORDS ✅

Pobrane najnowsze wersje (zamiast ORDS 25.4 z pierwotnej instrukcji). Obie obsługują APEX 24.2.

| Narzędzie | Wersja | Źródło | Katalog |
|---|---|---|---|
| SQLcl | 26.3.1 | https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip | `C:\deskflow\tools\sqlcl` |
| ORDS | 26.3 | https://download.oracle.com/otn_software/java/ords/ords-latest.zip | `C:\deskflow\tools\ords` |

Rozpakowanie:
- **SQLcl:** ZIP zawiera folder `sqlcl`, więc rozpakowujemy do `C:\deskflow\tools` i dostajemy `C:\deskflow\tools\sqlcl\bin\sql.exe`.
- **ORDS:** ZIP nie ma folderu głównego, więc rozpakowujemy **do** utworzonego `C:\deskflow\tools\ords` i dostajemy `C:\deskflow\tools\ords\bin\ords.exe`.

**Punkt kontrolny:** oba pliki `.exe` istnieją, bez podwójnego zagnieżdżenia (np. `sqlcl\sqlcl\bin`). ✅

## Krok 3: Zmienne środowiskowe ✅

Ustawiane w **zmiennych użytkownika**: Start → „Edytuj zmienne środowiskowe dla konta”, górna część okna. Nie wymaga to uprawnień administratora i nie wpływa na resztę systemu ani na instalację XE.

| Zmienna | Wartość | Uwagi |
|---|---|---|
| `JAVA_HOME` (nowa) | `C:\Program Files\Java\jdk-21` | SQLcl, ORDS i Liquibase mają używać Javy 21, a nie 25 |
| `Path` (istniejąca, nowy wpis) | `C:\deskflow\tools\sqlcl\bin` | |
| `Path` (istniejąca, nowy wpis) | `C:\deskflow\tools\ords\bin` | |

Po zmianie trzeba otworzyć **nowe** okno terminala, bo stare okna mają kopię zmiennych sprzed zmiany.

**Punkt kontrolny:** ✅
- `JAVA_HOME` wskazuje JDK 21.0.9,
- `C:\deskflow\tools\sqlcl\bin\sql.exe -version` → `SQLcl: Release 26.3.1.0`,
- `ords --version` → `ORDS: Release 26.3`.

## Krok 4: Polecenie `sqlcl` ✅

Instalacja XE ma własny, stary i niedziałający `sql.exe` w ścieżkach **systemowych**. Windows przeszukuje je przed ścieżkami użytkownika, więc polecenie `sql` zawsze uruchamia stary program (szczegóły w [02-problemy-i-rozwiazania.md](02-problemy-i-rozwiazania.md)).

Rozwiązanie: plik `C:\deskflow\tools\sqlcl\bin\sqlcl.cmd` z jedną linią:

```bat
@"%~dp0sql.exe" %*
```

`%~dp0` oznacza „folder, w którym leży ten plik”, a `%*` przekazuje wszystkie argumenty. Od teraz nowy SQLcl uruchamia się poleceniem **`sqlcl`**, a stary `sql` z XE zostaje nietknięty.

Przy zapisie w Notatniku trzeba wybrać typ „Wszystkie pliki (\*.\*)”, inaczej powstanie `sqlcl.cmd.txt`. Po aktualizacji SQLcl przez podmianę folderu plik trzeba utworzyć ponownie.

**Punkt kontrolny:** w nowym PowerShell `sqlcl -version` → `SQLcl: Release 26.3.1.0`.

## Krok 5: Dostęp jako SYS ✅

Utworzenie PDB, instalacja APEX i ORDS wymagają połączenia **SYS AS SYSDBA** z głównym kontenerem (`CDB$ROOT`, service name `XE`). Konto SYSTEM nie wystarczy.

Okazało się, że hasło SYS różni się od hasła SYSTEM (`ORA-01017`). Hasło SYS ustawiamy ponownie przez uwierzytelnienie systemu operacyjnego. Konto Windows, które instalowało XE, należy do lokalnej grupy `ORA_DBA`, więc może połączyć się jako SYSDBA bez hasła, tylko lokalnie:

```powershell
$env:ORACLE_SID = "XE"
sqlplus / as sysdba
```

```sql
alter user sys identified by "<nowe_haslo>";
exit
```

Wskazówki: w haśle unikać znaków `@`, `"` i `/`. Hasło przechowywać prywatnie (np. menedżer haseł), nigdy w repozytorium.

Następnie w SQL Developerze nowe połączenie:

| Pole | Wartość |
|---|---|
| Name | `XE_ROOT_SYS` |
| Username / Role | `SYS` / `SYSDBA` |
| Hostname / Port | `localhost` / `1521` |
| Service name | `XE` |

> Wskazówka: SQL Developer nie przyjął nazwy połączenia ze spacjami i nawiasami (np. `XE ROOT (SYS)`). Bezpieczniej używać tylko liter, cyfr i podkreśleń.

Reset hasła SYS przez `sqlplus / as sysdba` zakończył się sukcesem. ✅

**Punkt kontrolny:**
```sql
select sys_context('USERENV','CON_NAME') as kontener from dual;
```
Wynik: `CDB$ROOT`.

## Krok 6: Osobna PDB `DESKFLOW` ✅

Cel: odizolować projekt od istniejącej `XEPDB1`. W razie problemów można usunąć tylko tę jedną PDB.

1. Utworzyć katalog na pliki: `<ORACLE_BASE>\oradata\XE\DESKFLOW` (u nas na dysku D:, obok `XEPDB1` i `pdbseed`).
   > Uwaga: folder docelowy dla `file_name_convert` utworzyliśmy **ręcznie, przed** `create pluggable database`. Polecenie kopiuje pliki do wskazanej ścieżki, więc folder powinien już istnieć.
2. W połączeniu `XE_ROOT_SYS` (kontener `CDB$ROOT`) wykonać jako skrypt (F5 w SQL Developerze). Hasło administratora PDB wpisać tylko lokalnie:

```sql
create pluggable database DESKFLOW
  admin user deskflow_admin identified by "<haslo>"
  file_name_convert = ('<ORACLE_BASE>\oradata\XE\pdbseed\',
                       '<ORACLE_BASE>\oradata\XE\DESKFLOW\');

alter pluggable database DESKFLOW open;
alter pluggable database DESKFLOW save state;
```

- `create pluggable database` kopiuje pustą bazę wzorcową (`pdbseed`) do nowego katalogu.
- `open` otwiera PDB.
- `save state` sprawia, że PDB otwiera się sama po restarcie komputera.

**Punkt kontrolny:**
```sql
select con_id, name, open_mode from v$pdbs;
```
Oczekiwane i uzyskane:

| CON_ID | NAME | OPEN_MODE |
|---|---|---|
| 2 | `PDB$SEED` | READ ONLY |
| 3 | `XEPDB1` | READ WRITE |
| 4 | **`DESKFLOW`** | **READ WRITE** |

Listener rejestruje nową usługę. W PowerShell:
```powershell
lsnrctl status
```
Na liście usług powinna być `deskflow`. Dzięki temu można się łączyć przez `localhost:1521/deskflow`.

Pliki nowej PDB w `<ORACLE_BASE>\oradata\XE\DESKFLOW`: SYSTEM ~270 MB, SYSAUX ~330 MB, UNDO 100 MB, TEMP 35 MB.

## Krok 7: Instalacja APEX 24.2 w `DESKFLOW` ✅

Instalacja przez SQLcl, z katalogu z instalatorem APEX, żeby skrypty pomocnicze były widoczne:

```powershell
Set-Location C:\apex\apex
sqlcl /nolog
```

```sql
connect sys@//localhost:1521/deskflow as sysdba
show con_name
@apexins.sql SYSAUX SYSAUX TEMP /i/
```

- `show con_name` musi pokazać `DESKFLOW`, a nie `CDB$ROOT` ani `XEPDB1`.
- Parametry: tablespace dla APEX, tablespace dla plików, tablespace tymczasowy, wirtualna ścieżka obrazów `/i/`.
- Instalatora nie przerywać. U nas trwał ok. **16 minut**.
- **Nie używać własnego `spool`.** `apexins.sql` sam zarządza spoolem i zapisuje log w katalogu instalatora (`C:\apex\apex\install<data_godzina>.log`, u nas ok. 470 KB). Własny `spool` daje pusty plik (szczegóły w [02-problemy-i-rozwiazania.md](02-problemy-i-rozwiazania.md)).

**Punkt kontrolny:**
```sql
select version, status from dba_registry where comp_id = 'APEX';
```
Uzyskane: **APEX 24.2.0, `VALID`**, schemat `APEX_240200`.

Sprawdzenie logu instalatora pod kątem błędów (PowerShell):
```powershell
Get-ChildItem C:\apex\apex\install*.log | Select-String -Pattern 'ORA-\d+|PLS-\d+|SP2-\d+'
```
Uzyskane: 0 trafień. Przy błędzie zachować log i nie uruchamiać instalatora ponownie w ciemno.

> Wersja w laboratorium to **24.2.0**, a w firmie **24.2.8**. Patch set jest dostępny tylko przez Oracle Support. Dla PoC nie ma to znaczenia, ale eksportu firmowej aplikacji z 24.2.8 nie da się zaimportować do 24.2.0 (zob. [00-plan-i-kryteria.md](00-plan-i-kryteria.md)).

## Krok 8: Konta APEX w `DESKFLOW` ✅

W SQLcl, nadal z katalogu `C:\apex\apex`, połączenie jako SYS do `deskflow`:

| Element | Stan |
|---|---|
| `APEX_PUBLIC_USER`: hasło i odblokowanie | ✅ |
| `@apxchpwd.sql` (administrator instancji) | ✅ |
| `@apex_rest_config.sql` (konta REST) | ✅ |

**1. Administrator instancji APEX:**
```sql
@apxchpwd.sql
```
Ustawia administratora `ADMIN`, adres e-mail i osobne hasło. W prywatnym laboratorium jako e-mail podano placeholder (`ADMIN`). To wystarcza, bo e-mail służy np. do resetu hasła, a lab nie ma skonfigurowanej poczty.

**2. Konto `APEX_PUBLIC_USER`:**
```sql
alter user APEX_PUBLIC_USER identified by "<haslo>" account unlock;
```
Jedno polecenie ustawia hasło i odblokowuje konto. Polecenie `password APEX_PUBLIC_USER` w SQLcl 26.3.1 nie działa (zob. [02-problemy-i-rozwiazania.md](02-problemy-i-rozwiazania.md), problem 8). SQLcl może nie wypisać komunikatu „altered”, więc wynik trzeba sprawdzić:
```sql
select username, account_status, password_change_date
from dba_users where username = 'APEX_PUBLIC_USER';
```
Oczekiwane: `OPEN` i dzisiejsza data w `PASSWORD_CHANGE_DATE` (format RR/MM/DD).

Potem wyczyścić historię SQLcl, bo zapamiętała polecenie razem z hasłem:
```sql
history clear
```

**3. Konta REST:**
```sql
@apex_rest_config.sql
```
Pyta o hasła kont technicznych `APEX_LISTENER` i `APEX_REST_PUBLIC_USER`.

Każde konto ma osobne hasło, przechowywane prywatnie.

**Punkt kontrolny:**
```sql
select username, account_status, password_change_date
from dba_users
where username in ('APEX_LISTENER', 'APEX_PUBLIC_USER', 'APEX_REST_PUBLIC_USER');
```
Uzyskane: wszystkie trzy konta `OPEN`, hasła zmienione w dniu instalacji.

```sql
select user_name, email_address
from apex_240200.wwv_flow_fnd_user
where security_group_id = 10 and user_name = 'ADMIN';
```
Uzyskane: 1 wiersz. `security_group_id = 10` to wewnętrzny workspace administracyjny APEX (INTERNAL), w którym istnieje administrator instancji.

> **Dobra praktyka:** nie wpisywać hasła jako osobnej linii w zwykłym prompcie `SQL>`. Wtedy jest widoczne na ekranie i trafia do historii. Jeśli tak się stanie, wybrać inne hasło. Hasła wpisywać tylko w monitach. Nie zostawiać ich w arkuszach SQL Developera i **nie zapisywać takich arkuszy w repozytorium**. Arkusz z poleceniem `alter user ... identified by ...` po użyciu wyczyścić albo zamknąć bez zapisu.

## Krok 9: Instalacja i uruchomienie ORDS 26.3.1 ✅

ORDS działa na Windowsie i łączy się z PDB `DESKFLOW` przez `localhost:1521`. Konfiguracja leży poza programem, w `C:\deskflow\config\ords`.

**1. Instalacja (PowerShell):**
```powershell
ords --config C:\deskflow\config\ords install --interactive
```

Kierować się nazwami pól, bo numery opcji różnią się między wydaniami. Pułapki, na które trafiliśmy:

1. **Wybór bazy:** pierwsze pytanie proponuje domyślnie `[1]` XE z `tnsnames.ora`, czyli **kontener główny (CDB)**. Trzeba wybrać **`S` (Specify)**, potem Basic, `localhost`, `1521`, service name **`deskflow`**.
2. **Administrator bazy:** wpisać `SYS AS SYSDBA` w jednej linii.
3. **Ekran podsumowania (opcje `[1]`–`[9]`):**

   | Opcja | Ustawienie |
   |---|---|
   | `[3]` hasło `ORDS_PUBLIC_USER` | zostawiono `<generate>`. **Lepiej od razu podać własne hasło** (zob. [02-problemy-i-rozwiazania.md](02-problemy-i-rozwiazania.md), problem 9) |
   | `[4]` tablespace'y | `SYSAUX` / `TEMP` (domyślne) |
   | `[5]` Database Actions | domyślne |
   | `[6]` Standalone | Yes, HTTP, port `8080` |
   | **`[9]` APEX static resources** | **`C:\apex\apex\images`**. Domyślnie jest `null`, a wtedy APEX wyświetla się bez stylów. |

   Na koniec `A`, żeby zatwierdzić.

Wynik w konfiguracji:
- `global/settings.xml`: `standalone.static.path = C:\apex\apex\images`, `standalone.http.port = 8080`
- `databases/default/pool.xml`: użytkownik `ORDS_PUBLIC_USER`, service `deskflow`, `plsql.gateway.mode = proxied`. Hasło jest zapisane w wallecie, nie w pliku XML.

> Zmiana względem pierwotnej instrukcji: obrazy APEX są w `C:\apex\apex\images`, a nie w `C:\deskflow\tools\apex\images`, bo APEX został w swoim dotychczasowym katalogu. Obrazy muszą pochodzić z tej samej wersji APEX co baza.

Po instalacji pula `default` była `INVALID` (`ORA-01017` dla `ORDS_PUBLIC_USER`). Opis i naprawa: [02-problemy-i-rozwiazania.md](02-problemy-i-rozwiazania.md), problem 9.

**2. Uruchomienie serwera (także na co dzień):**
```powershell
ords --config C:\deskflow\config\ords serve
```
Bez parametrów, bo port i ścieżka obrazów są zapisane w konfiguracji. Okno zostaje otwarte, a Ctrl+C zatrzymuje serwer.

**Punkt kontrolny:** ✅
- w logu ORDS: `/ords/ => default => VALID`,
- `http://localhost:8080/i/apex_version.txt` → `Oracle APEX Version: 24.2`,
- `http://localhost:8080/ords/apex_admin` → HTTP 200, strona „Oracle APEX Administration Services”.

**Uwagi:**
- ORDS nasłuchuje na `0.0.0.0:8080`, czyli na wszystkich interfejsach sieciowych. Dostęp z sieci blokuje zapora Windows. Ewentualnie później można ograniczyć nasłuch do `127.0.0.1`.
- Niegroźne ostrzeżenia w logu, do zignorowania w labie: brak folderu `doc_root` oraz `jdbc.MaxLimit=10` „not adequate for production”.

## Krok 10: Workspace'y DEV i TEST oraz połączenia

| Część | Stan |
|---|---|
| Workspace'y i schematy w APEX | ✅ |
| Połączenia w SQL Developerze | 🔄 w trakcie |

### 10a. Workspace'y ✅

1. Zalogować się jako `ADMIN` na `http://localhost:8080/ords/apex_admin`.
2. **Manage Workspaces → Create Workspace**, dwa razy, za każdym razem z nowym schematem (Re-use existing schema: **No**, quota 100 MB):

   | Workspace | Schemat bazy | Administrator workspace | Rola |
   |---|---|---|---|
   | `DESK_A_DEV` | `DESK_A_DEV` | `DEV_ADMIN` | budowa aplikacji |
   | `DESK_A_TEST` | `DESK_A_TEST` | `TEST_ADMIN` | odtwarzanie i sprawdzanie wydań |

Kreator tworzy dla każdego schematu własny tablespace o nazwie `APEX_<numer>`.

**Trzy rodzaje haseł**, łatwo je pomylić:

| Hasło | Do czego | Gdzie się używa |
|---|---|---|
| Administrator instancji (`ADMIN`) | zarządzanie całym APEX | `http://localhost:8080/ords/apex_admin` |
| Hasło schematu (`DESK_A_DEV`, `DESK_A_TEST`) | konto **w bazie danych** | SQL Developer, SQLcl, Liquibase |
| Administrator workspace (`DEV_ADMIN`, `TEST_ADMIN`) | konto **w APEX** | `http://localhost:8080/ords/apex` |

**Punkt kontrolny:** ✅ sprawdzone tylko do odczytu, przez uwierzytelnienie systemowe:
```powershell
$env:ORACLE_SID = "XE"
sqlplus -s / as sysdba
```
```sql
alter session set container = DESKFLOW;

select workspace, created_on from apex_workspaces
where workspace in ('DESK_A_DEV', 'DESK_A_TEST');

select username, account_status, default_tablespace from dba_users
where username in ('DESK_A_DEV', 'DESK_A_TEST');

select workspace_name, user_name, is_admin from apex_workspace_apex_users
where workspace_name in ('DESK_A_DEV', 'DESK_A_TEST');
```
Uzyskane:
- oba workspace'y z datą utworzenia z dnia instalacji;
- `DESK_A_DEV` i `DESK_A_TEST` mają status `OPEN`, każdy z własnym tablespace `APEX_<numer>`;
- `DEV_ADMIN` i `TEST_ADMIN` mają `IS_ADMIN = Yes`.

> Wskazówka techniczna: przy przekazywaniu skryptu do `sqlplus` z PowerShella (np. przez potok) pierwsza linia może dostać znak BOM i skończyć się błędem `SP2-0734`. Skrypt warto zaczynać od pustej linii albo komentarza.

### 10b. Połączenia w SQL Developerze ✅

| Ustawienie | DEV | TEST |
|---|---|---|
| Name | `DESKFLOW_A_DEV` | `DESKFLOW_A_TEST` |
| Username / Role | `DESK_A_DEV` / default | `DESK_A_TEST` / default |
| Password | hasło schematu z kreatora workspace | hasło schematu z kreatora workspace |
| Hostname / Port | `localhost` / `1521` | `localhost` / `1521` |
| Service name | **`deskflow`** | **`deskflow`** |

Service name to `deskflow`, a nie `FREEPDB1` jak w pierwotnej instrukcji. Nazwy połączeń są z podkreśleniami, tak jak `XE_ROOT_SYS`.

**Punkt kontrolny:** ✅ w arkuszu każdego połączenia:
```sql
select user, sys_context('USERENV','CON_NAME') as pdb from dual;
```
Uzyskane: `DESK_A_DEV` / `DESKFLOW` oraz `DESK_A_TEST` / `DESKFLOW`.

> **Baza, APEX, ORDS i workspace'y są gotowe.** Dalej: narzędzia do wersjonowania.

## Krok 11: Git for Windows ✅ (inicjalizacja repo: ⏳)

SQLcl Projects i Liquibase wywołują polecenie `git`, więc Git musi być w `Path`. Git dołączony do GitHub Desktop się do tego nie nadaje. Leży w katalogu zależnym od wersji aplikacji (`...\GitHubDesktop\app-<wersja>\...`), który zmienia się przy każdej aktualizacji GitHub Desktop, więc wpis w `Path` przestałby działać.

1. Zainstalować Git for Windows z oficjalnej strony (`https://git-scm.com/download/win`), z opcją dodania Gita do `Path`.
2. W nowym PowerShell:
   ```powershell
   git --version
   Get-Command git
   ```
   `Get-Command` ma wskazywać instalację Git for Windows, nie GitHub Desktop.

   Uzyskane: ✅ `git version 2.56.1.windows.1`, z `C:\Program Files\Git\cmd` (w systemowym `Path`). Globalne `user.name` i `user.email` były już ustawione. Git for Windows i GitHub Desktop korzystają ze wspólnego pliku `~/.gitconfig`, więc konfiguracja przeszła sama. `init.defaultBranch` nie jest ustawione, dlatego repozytorium zakładamy z jawnym `-b main`.
3. Zainicjalizować repozytorium w `C:\deskflow\repo`, na jeden z dwóch sposobów:
   - GitHub Desktop: **File → Add local repository** → wskazać `C:\deskflow\repo` → „create a repository here”,
   - albo w PowerShell:
     ```powershell
     Set-Location C:\deskflow\repo
     git init -b main
     ```

Repozytorium obejmuje tylko `C:\deskflow\repo`. Pozostałe katalogi (`tools`, `config`, `secrets`, `logs`, `backups`) zostają lokalnie.

**Punkt kontrolny:** `git --version` działa w nowym terminalu, a `C:\deskflow\repo` jest repozytorium Git na gałęzi `main`.

## Krok 12: Liquibase Community 🔄 w trakcie

| Część | Stan |
|---|---|
| ZIP rozpakowany, `liquibase.bat --version` działa | ✅ |
| Polecenie `liquibase` z `Path` | ✅ po poprawieniu nazwy folderu (problem 10) |
| Sterownik Oracle (`lpm add`) | 🔄 w trakcie |

1. Pobrać Liquibase Community (ZIP) i rozpakować do `C:\deskflow\tools\liquibase`. Uwaga na pisownię: **liqui*b*ase**, nie „liquid” (zob. [02-problemy-i-rozwiazania.md](02-problemy-i-rozwiazania.md), problem 10).

   Pobrany plik: `liquibase-5.0.4.zip`, ok. 8 MB. Community 5 jest „odchudzona” i nie zawiera sterowników baz danych.

   Uzyskane: ✅ `liquibase.bat --version` → **Liquibase 5.0.4**, Java Home JDK 21.0.9. W sekcji *Libraries* są tylko biblioteki wewnętrzne i H2, **bez sterownika Oracle**. Tak ma być: sterownik dodaje punkt 4.
2. Dodać do `Path` użytkownika katalog zawierający `liquibase.bat`. W zależności od paczki to katalog główny albo `bin`. Istniejących wpisów nie usuwać.
3. W nowym PowerShell:
   ```powershell
   liquibase --version
   Get-Command liquibase
   ```
   Uzyskane: ✅ `Get-Command` → `C:\deskflow\tools\liquibase\liquibase.bat`. `liquibase --version` → 5.0.4, Liquibase Home `C:\deskflow\tools\liquibase`, Java Home JDK 21.0.9. W tej paczce `liquibase.bat` leży w katalogu głównym, więc do `Path` trafia sam `C:\deskflow\tools\liquibase`.
4. Dodać sterownik Oracle w katalogu repozytorium:
   ```powershell
   Set-Location C:\deskflow\repo
   liquibase lpm add liquibase-oracle
   ```
   Manifest zależności zostaje w repozytorium. Pobrane biblioteki (`liquibase_libs/`) nie są publikowane.

**Punkt kontrolny:** `liquibase --version` podaje wersję, a zależność Oracle jest pobrana. Sam wynik `--version` nie dowodzi poprawnego połączenia z bazą. To potwierdzi dopiero pierwszy changelog.

## Dalsze kroki ⏳

- Codzienny start i zatrzymanie (usługa XE startuje sama; ORDS uruchamiany ręcznie).
