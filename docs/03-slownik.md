# Słownik pojęć

Krótkie wyjaśnienia pojęć, które pojawiają się w projekcie.

## CDB i PDB

Od Oracle 12c baza jest zbudowana jak **blok mieszkalny**:

- **CDB (Container Database)**, czyli `CDB$ROOT`: „administracja budynku”. Tu działają wspólne procesy i stąd zarządza się całością. Tylko z poziomu CDB można „dobudować” nową PDB. W Oracle XE service name głównego kontenera to `XE`.
- **PDB (Pluggable Database)**: „mieszkanie”. Samodzielna baza z własnymi schematami, użytkownikami i danymi. Aplikacje pracują w PDB.
- **`PDB$SEED`**: „mieszkanie wzorcowe”, tylko do odczytu, kopiowane przy tworzeniu nowej PDB.

W projekcie: `XEPDB1` to istniejąca PDB (np. schemat HR), a `DESKFLOW` to nowa PDB tylko dla tego projektu.

## SYS i SYSTEM

| Konto | Rola |
|---|---|
| **SYS** | właściciel słownika danych, najwyższe uprawnienia; loguje się z rolą `SYSDBA`. Wymagane do instalacji APEX, ORDS i tworzenia PDB. |
| **SYSTEM** | konto administracyjne o szerokich uprawnieniach (rola DBA), ale mniejszych niż SYS. |

Oba konta mogą mieć różne hasła. Żadnego z nich nie używamy do pracy aplikacji ani do uruchamiania Liquibase.

## SQL Developer, SQLcl i SQL\*Plus

| Narzędzie | Co to jest |
|---|---|
| **SQL Developer** | program z interfejsem graficznym do codziennej pracy z bazą |
| **SQLcl** (`sql`) | narzędzie wiersza poleceń, nowoczesny następca SQL\*Plus; ma wbudowany Liquibase (`lb`), eksport APEX (`apex export`) i SQLcl Projects (`project`) |
| **SQL\*Plus** (`sqlplus`) | klasyczne narzędzie wiersza poleceń, instalowane razem z bazą |

Narzędzia wiersza poleceń są potrzebne, bo tylko je da się zautomatyzować (np. „wdróż na TEST jednym poleceniem”). Do pisania kodu dalej używa się SQL Developera albo VS Code.

## ORDS

**Oracle REST Data Services**: serwer WWW (aplikacja Java), który pośredniczy między przeglądarką a bazą. Bez ORDS aplikacji APEX nie da się otworzyć w przeglądarce. W projekcie ORDS działa na Windowsie, na `http://localhost:8080`.

## APEX

**Oracle Application Express**: środowisko do budowy aplikacji webowych, które „żyje” wewnątrz bazy (metadane aplikacji to dane w tabelach). Dlatego zmian klikanych w APEX nie widać w Gicie, dopóki nie wyeksportuje się aplikacji do plików. Eksport `-split` z `READABLE_YAML` daje czytelne pliki per strona.

**Workspace**: przestrzeń robocza w APEX, powiązana z jednym lub kilkoma schematami bazy. Konto APEX to coś innego niż użytkownik bazy, nawet przy podobnej nazwie.

**Trzy rodzaje kont i haseł w projekcie:**
- **administrator instancji APEX** (`ADMIN`): zarządza całym APEX, loguje się na `/ords/apex_admin`;
- **schemat bazy** (np. `DESK_A_DEV`): konto w bazie danych, używane w SQL Developerze, SQLcl i Liquibase;
- **administrator workspace** (np. `DEV_ADMIN`): konto w APEX, do budowy aplikacji na `/ords/apex`.

## Path i JAVA_HOME

- **`Path`**: lista folderów, w których Windows szuka programów po wpisaniu nazwy w terminalu. Przeszukuje je po kolei (najpierw systemowe, potem użytkownika) i uruchamia **pierwszy** znaleziony program.
- **`JAVA_HOME`**: wskazuje, której instalacji Javy mają używać narzędzia napisane w Javie (SQLcl, ORDS, Liquibase). W projekcie: JDK 21.

Program dostaje kopię zmiennych w chwili uruchomienia, więc po zmianie trzeba otworzyć nowe okno terminala.

## Liquibase: changelog i changeset

- **Changeset**: pojedyncza, opisana zmiana bazy (np. „dodaj kolumnę PRIORYTET”), identyfikowana przez autora i id. Raz wykonany changeset nie jest wykonywany ponownie, chyba że ma `runOnChange:true`. Takie ustawienie stosuje się dla pakietów i widoków (`create or replace`), które mają się wgrywać po każdej zmianie pliku.
- **Changelog**: plik (lub drzewo plików) z listą changesetów w ustalonej kolejności. To „spis” wszystkich zmian bazy.

## DATABASECHANGELOG

Tabela, którą Liquibase tworzy w docelowym schemacie. Zapisuje, które changesety zostały wykonane, kiedy, i z jaką sumą kontrolną. Dzięki niej Liquibase wie, co jeszcze trzeba wdrożyć, a my wiemy, co jest na danym środowisku. Obok jest tabela `DATABASECHANGELOGLOCK`, która chroni przed dwoma równoczesnymi wdrożeniami.

## SQLcl Projects

Funkcja SQLcl (`project init / export / stage / release / deploy`) do CI/CD baz Oracle. Pod spodem używa Liquibase, ale sama eksportuje obiekty schematu i aplikacje APEX do plików i generuje changesety na podstawie różnic w Gicie.

## Drift

Rozjazd między tym, co jest w repozytorium, a tym, co faktycznie jest w bazie. Typowa przyczyna to zmiana wprowadzona bezpośrednio w bazie z pominięciem Gita.
