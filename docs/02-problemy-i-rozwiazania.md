# Problemy i rozwiązania

Dziennik problemów napotkanych podczas budowy środowiska i projektu. Każdy wpis ma format **Objaw / Przyczyna / Rozwiązanie / Wniosek**, żeby kolejna osoba mogła szybko znaleźć odpowiedź na ten sam problem.

---

## 1. Brak WSL2 i Dockera

- **Objaw:** `wsl --version` zwraca komunikat, że Podsystem Windows dla systemu Linux nie jest zainstalowany; polecenie `docker` nie istnieje.
- **Przyczyna:** komputer nigdy nie miał zainstalowanego WSL ani Docker Desktop.
- **Rozwiązanie:** niepotrzebne. Na komputerze działa już Oracle XE 21c, więc zrezygnowaliśmy z kontenera z Oracle Free 23ai (uzasadnienie w [01-srodowisko.md](01-srodowisko.md)).
- **Wniosek:** przed instalacją według gotowej instrukcji warto sprawdzić, co już jest na komputerze. Można w ten sposób pominąć najbardziej ryzykowne kroki.

---

## 2. Polecenie `sql` uruchamia stary, niedziałający SQLcl

- **Objaw:** `sql -version` kończy się błędem `Could not find or load main class oracle.dbtools.raptor.scriptrunner.cmdline.SqlCli`, mimo że nowy SQLcl 26.3.1 jest rozpakowany i dodany do `Path`.
- **Przyczyna:** instalacja Oracle XE ma własny `sql.exe` w folderze `bin` swojego katalogu domowego, a ten folder jest w **systemowym** `Path`. Windows przeszukuje ścieżki systemowe przed ścieżkami użytkownika i uruchamia pierwszy znaleziony program o danej nazwie. Do nowego SQLcl nigdy nie dochodzi.
- **Rozwiązanie:** plik `sqlcl.cmd` w `C:\deskflow\tools\sqlcl\bin` z treścią `@"%~dp0sql.exe" %*`. Nowy SQLcl uruchamia się poleceniem `sqlcl`.
  - Odrzucona alternatywa 1: **usunięcie wpisu XE z systemowego `Path`**. W tym folderze są inne potrzebne narzędzia (`sqlplus`, `lsnrctl`), a zmiana wymaga uprawnień administratora.
  - Odrzucona alternatywa 2: **alias w profilu PowerShell**. Zasady wykonywania skryptów (execution policy) są na tym komputerze niezdefiniowane, czyli domyślnie `Restricted`, więc profil by się nie uruchomił. Zmiana execution policy to zmiana ustawień bezpieczeństwa, której chcieliśmy uniknąć.
- **Wniosek:** gdy dwa programy mają tę samą nazwę, `Get-Command <nazwa>` pokazuje, który faktycznie się uruchomi. Najbezpieczniej nadać nowemu narzędziu inną nazwę niż ruszać systemowy `Path`.

---

## 3. `JAVA_HOME` nie zapisało się za pierwszym razem

- **Objaw:** po ustawieniu zmiennych `Path` zawierał nowe wpisy, ale zmiennej `JAVA_HOME` nie było ani w zmiennych użytkownika, ani w systemowych.
- **Przyczyna:** najpewniej pominięte ostatnie „OK” albo zmienna utworzona w innym miejscu okna.
- **Rozwiązanie:** ponowne dodanie przez „Nowa…” w górnej części okna (zmienne użytkownika): `JAVA_HOME` = `C:\Program Files\Java\jdk-21`. Weryfikacja odczytem zmiennej z rejestru użytkownika i uruchomieniem `java -version` z tej ścieżki (21.0.9).
- **Wniosek:** po zmianie zmiennych zawsze otwierać **nowe** okno terminala i sprawdzić wynik, bo stare okna nie widzą zmian.

---

## 4. APEX nie jest zainstalowany, mimo plików w `C:\apex`

- **Objaw:** `select comp_id, version, status from dba_registry where comp_id = 'APEX';` nie zwraca wierszy, choć w `C:\apex\apex` są pliki APEX 24.2 (`apex_version.txt`).
- **Przyczyna:** `C:\apex` zawiera tylko rozpakowany **instalator**. Oracle XE 21c nie ma APEX w standardzie, a sam instalator nigdy nie został uruchomiony w bazie.
- **Rozwiązanie:** instalacja APEX w nowej PDB `DESKFLOW` (krok 7 w [01-srodowisko.md](01-srodowisko.md)).
- **Wniosek:** APEX „żyje” wewnątrz bazy. Pliki na dysku to tylko instalator i zasoby statyczne (`images`) dla ORDS.

---

## 5. Połączenie z `XEPDB1` zamiast z głównym kontenerem

- **Objaw:** `select con_id, name, open_mode from v$pdbs;` pokazał tylko jeden wiersz (`XEPDB1`), bez `PDB$SEED`.
- **Przyczyna:** połączenie w SQL Developerze używało service name `XEPDB1`. Z wnętrza PDB widać tylko ją samą. Nowej PDB nie da się utworzyć z innej PDB, tylko z kontenera głównego `CDB$ROOT`.
- **Rozwiązanie:** osobne połączenie z service name **`XE`**. Weryfikacja: `select sys_context('USERENV','CON_NAME') from dual;` → `CDB$ROOT`.
- **Wniosek:** przed operacjami administracyjnymi zawsze sprawdzić, w którym kontenerze się jest.

---

## 6. SYS ma inne hasło niż SYSTEM (`ORA-01017`) ✅ rozwiązane

- **Objaw:** połączenie `SYS` / `SYSDBA` / service `XE` z hasłem konta SYSTEM kończy się `ORA-01017: niepoprawna nazwa użytkownika/hasło; odmowa zalogowania`.
- **Przyczyna:** hasła SYS i SYSTEM są różne (np. zmienione kiedyś osobno), a hasła SYS nie da się odczytać, bo Oracle przechowuje tylko jego skrót.
- **Rozwiązanie:** uwierzytelnienie systemu operacyjnego. Konto Windows, które instalowało XE, należy do lokalnej grupy `ORA_DBA`, a w `sqlnet.ora` jest `SQLNET.AUTHENTICATION_SERVICES = (NTS)`. Dzięki temu lokalnie działa logowanie bez hasła:
  ```powershell
  $env:ORACLE_SID = "XE"
  sqlplus / as sysdba
  ```
  ```sql
  alter user sys identified by "<nowe_haslo>";
  ```
  Następnie nowe hasło w połączeniu SQL Developera `XE_ROOT_SYS`. Reset zakończył się sukcesem.
- **Wniosek:** SYSTEM nie zastąpi SYS, bo instalatory APEX i ORDS wymagają `SYS AS SYSDBA`. Zapomniane hasło SYS w lokalnej bazie da się bezpiecznie zresetować przez grupę `ORA_DBA`, bez reinstalacji.

---

## 7. Pusty log przy instalacji APEX (własny `spool`)

- **Objaw:** `spool C:\deskflow\logs\apex-install.log` przed `@apexins.sql` dał pusty plik, a `spool off` na końcu zwrócił `not spooling currently`.
- **Przyczyna:** `apexins.sql` sam zarządza spoolem. Na starcie zamyka bieżący spool i zapisuje własny log w katalogu instalatora jako `install<data_godzina>.log` (u nas ok. 470 KB).
- **Rozwiązanie:** log odczytany z `C:\apex\apex` i przeszukany pod kątem błędów:
  ```powershell
  Get-ChildItem C:\apex\apex\install*.log | Select-String -Pattern 'ORA-\d+|PLS-\d+|SP2-\d+'
  ```
  Wynik: 0 trafień. Instalacja poprawna (`dba_registry`: APEX 24.2.0 `VALID`).
- **Wniosek:** przy `apexins.sql` nie używać własnego `spool`. Po instalacji sprawdzać log z katalogu instalatora i przeszukać go pod kątem `ORA-`, `PLS-` i `SP2-`.

---

## 8. `password APEX_PUBLIC_USER` nie działa w SQLcl 26.3.1

- **Objaw:** polecenie `password APEX_PUBLIC_USER` (zmiana hasła innego użytkownika, jako SYS) kończy się `Error: An unexpected error occurred while processing the command.` Wynik był taki sam w trzech próbach.
- **Przyczyna:** błąd lub ograniczenie polecenia `password` w SQLcl 26.3.1 przy zmianie hasła innego użytkownika. Dokładnej przyczyny nie ustalono.
- **Rozwiązanie:** jedno polecenie SQL zamiast dwóch:
  ```sql
  alter user APEX_PUBLIC_USER identified by "<haslo>" account unlock;
  ```
  SQLcl nie wypisał komunikatu „altered”, dlatego wynik sprawdzony zapytaniem:
  ```sql
  select username, account_status, password_change_date
  from dba_users where username = 'APEX_PUBLIC_USER';
  ```
  Wynik: `OPEN`, dzisiejsza data. Następnie `history clear`, bo SQLcl zapisuje w historii pełne polecenie razem z hasłem.
- **Wniosek:** po `alter user` w SQLcl zawsze sprawdzać `dba_users`, a po poleceniu z hasłem czyścić historię (`history clear`). Hasła nie wpisywać jako osobnej linii w prompcie `SQL>`, bo trafia na ekran. Jeśli tak się stanie, wybrać inne hasło.

---

## 9. Pula ORDS `INVALID` po instalacji (`ORA-01017` dla `ORDS_PUBLIC_USER`)

- **Objaw:** po `ords ... install --interactive` i `serve` pula `default` ma status `INVALID` z `ORA-01017` dla `ORDS_PUBLIC_USER`. Jednocześnie w logu jest ostrzeżenie: `Secrets marked for obfuscation using ! at the start of the value is no longer supported, use 'ords config secret db.password'`.
- **Przyczyna (hipoteza, niepotwierdzona):** hasło wygenerowane przez instalator (`<generate>`) zaczynało się od `!`, a ORDS 26 interpretuje `!` na początku wartości jako stary znacznik zaciemnienia i odczytuje hasło błędnie.
- **Rozwiązanie:**
  1. Zatrzymać ORDS (Ctrl+C).
  2. Jako SYS w PDB `deskflow`, z hasłem **bez `!` na początku**:
     ```sql
     alter user ORDS_PUBLIC_USER identified by "<haslo>" account unlock;
     history clear
     ```
  3. Zapisać to samo hasło w konfiguracji ORDS (polecenie zapyta o nie):
     ```powershell
     ords --config C:\deskflow\config\ords config secret db.password
     ```
     Komunikat: `The setting named: db.password was set to: ****** in configuration: default`.
  4. Uruchomić ponownie: `ords --config C:\deskflow\config\ords serve`. W logu: `/ords/ => default => VALID`.
- **Wniosek:** w instalatorze ORDS 26 na ekranie podsumowania (opcja `[3]`) lepiej od razu ustawić własne hasło `ORDS_PUBLIC_USER` zamiast `<generate>`. Hasło do puli zmienia się poleceniem `ords config secret db.password`, a nie edycją plików XML.

---

## 10. Polecenie `liquibase` nierozpoznane mimo wpisu w `Path` ✅ rozwiązane

- **Objaw:** `liquibase --version` w nowym terminalu kończy się błędem „not recognized”, choć `liquibase.bat` istnieje i uruchomiony z pełnej ścieżki działa.
- **Przyczyna:** literówka. Folder rozpakowano jako `C:\deskflow\tools\liquidbase` („liquid”), a wpis w `Path` to `C:\deskflow\tools\liquibase`. Windows nie znajduje programu w nieistniejącym katalogu.
- **Rozwiązanie:** zmiana nazwy folderu na `liquibase`, bez zmian w `Path`. Potem nowe okno PowerShell. Weryfikacja: `Get-Command liquibase` → `C:\deskflow\tools\liquibase\liquibase.bat`, a `liquibase --version` → 5.0.4.
- **Wniosek:** przy „command not recognized” najpierw porównać dokładną ścieżkę w `Path` z faktyczną lokalizacją programu:
  ```powershell
  Get-ChildItem C:\deskflow\tools -Filter liquibase.bat -Recurse | Select-Object FullName
  ```
