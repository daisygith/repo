--liquibase formatted sql

--changeset deskflow:pkg_zgloszenia_spec runOnChange:true splitStatements:false
--comment: Specyfikacja pakietu z logiką zgłoszeń
create or replace package pkg_zgloszenia
as
    ----------------------------------------------------------------------------
    -- Logika biznesowa zgłoszeń DeskFlow.
    -- Wszystkie zmiany statusu, przypisania i komentarze przechodzą przez ten
    -- pakiet, żeby reguły były w jednym miejscu (a nie na stronach APEX).
    --
    -- Cykl życia zgłoszenia:
    --   NOWE       -> W_TOKU                (wymaga przypisanej osoby)
    --   W_TOKU     -> OCZEKUJE | ROZWIAZANE
    --   OCZEKUJE   -> W_TOKU                (także automatycznie, gdy zgłaszający doda komentarz)
    --   ROZWIAZANE -> ZAMKNIETE | W_TOKU    (zgłaszający potwierdza albo otwiera ponownie)
    --   ZAMKNIETE  -> (koniec)
    ----------------------------------------------------------------------------

    c_nowe        constant varchar2(20) := 'NOWE';
    c_w_toku      constant varchar2(20) := 'W_TOKU';
    c_oczekuje    constant varchar2(20) := 'OCZEKUJE';
    c_rozwiazane  constant varchar2(20) := 'ROZWIAZANE';
    c_zamkniete   constant varchar2(20) := 'ZAMKNIETE';

    c_rola_zglaszajacy  constant varchar2(20) := 'ZGLASZAJACY';
    c_rola_odbierajacy  constant varchar2(20) := 'ODBIERAJACY_SD';
    c_rola_admin        constant varchar2(20) := 'ADMIN';

    -- Kody błędów (raise_application_error)
    e_brak_obiektu          constant pls_integer := -20001;
    e_niedozwolone_przejscie constant pls_integer := -20002;
    e_brak_uprawnien        constant pls_integer := -20003;
    e_brak_przypisania      constant pls_integer := -20004;
    e_zamkniete             constant pls_integer := -20005;

    -- Tworzy nowe zgłoszenie (status NOWE) i zwraca jego ID.
    function utworz (
        p_tytul           in zgloszenia.tytul%type,
        p_opis            in zgloszenia.opis%type,
        p_kategoria_id    in zgloszenia.kategoria_id%type,
        p_zglaszajacy_id  in zgloszenia.zglaszajacy_id%type
    ) return zgloszenia.id%type;

    -- Przypisuje zgłoszenie pracownikowi service desku. Może to zrobić ODBIERAJACY_SD lub ADMIN.
    procedure przypisz (
        p_zgloszenie_id  in zgloszenia.id%type,
        p_przypisany_id  in zgloszenia.przypisany_id%type,
        p_uzytkownik_id  in uzytkownicy.id%type
    );

    -- Zmienia status zgodnie z cyklem życia i uprawnieniami użytkownika.
    procedure zmien_status (
        p_zgloszenie_id  in zgloszenia.id%type,
        p_nowy_status    in zgloszenia.status%type,
        p_uzytkownik_id  in uzytkownicy.id%type
    );

    -- Dodaje komentarz. Wewnętrzne komentarze może dodać tylko service desk.
    -- Komentarz zgłaszającego przy statusie OCZEKUJE przywraca status W_TOKU.
    procedure dodaj_komentarz (
        p_zgloszenie_id  in zgloszenia.id%type,
        p_autor_id       in uzytkownicy.id%type,
        p_tresc          in komentarze.tresc%type,
        p_wewnetrzny     in komentarze.wewnetrzny%type default 'N'
    );

    -- 'T', jeśli przejście statusu jest zgodne z cyklem życia (bez sprawdzania uprawnień).
    -- Do użycia w warunkach APEX, np. czy pokazać przycisk.
    function czy_dozwolone_przejscie (
        p_z_statusu   in zgloszenia.status%type,
        p_na_status   in zgloszenia.status%type
    ) return varchar2;

    -- 'T', jeśli użytkownik może wykonać daną zmianę statusu tego zgłoszenia.
    function czy_moze_zmienic_status (
        p_zgloszenie_id  in zgloszenia.id%type,
        p_nowy_status    in zgloszenia.status%type,
        p_uzytkownik_id  in uzytkownicy.id%type
    ) return varchar2;

end pkg_zgloszenia;
--rollback drop package pkg_zgloszenia;
