--liquibase formatted sql

--changeset deskflow:pkg_zgloszenia_body runOnChange:true splitStatements:false
--comment: Ciało pakietu z logiką zgłoszeń
create or replace package body pkg_zgloszenia
as
    ----------------------------------------------------------------------------
    -- Funkcje pomocnicze (prywatne)
    ----------------------------------------------------------------------------

    -- Zwraca rolę aktywnego użytkownika albo zgłasza błąd.
    function rola_uzytkownika (p_uzytkownik_id in uzytkownicy.id%type)
        return uzytkownicy.rola%type
    is
        l_rola uzytkownicy.rola%type;
    begin
        select u.rola
          into l_rola
          from uzytkownicy u
         where u.id = p_uzytkownik_id
           and u.aktywny = 'T';
        return l_rola;
    exception
        when no_data_found then
            raise_application_error(e_brak_obiektu,
                'Nie znaleziono aktywnego użytkownika o ID ' || p_uzytkownik_id || '.');
    end rola_uzytkownika;

    function czy_service_desk (p_rola in uzytkownicy.rola%type) return boolean
    is
    begin
        return p_rola in (c_rola_odbierajacy, c_rola_admin);
    end czy_service_desk;

    -- Pobiera zgłoszenie (opcjonalnie z blokadą wiersza) albo zgłasza błąd.
    function pobierz_zgloszenie (
        p_zgloszenie_id in zgloszenia.id%type,
        p_zablokuj      in boolean default false
    ) return zgloszenia%rowtype
    is
        l_zgl zgloszenia%rowtype;
    begin
        if p_zablokuj then
            select * into l_zgl from zgloszenia where id = p_zgloszenie_id for update;
        else
            select * into l_zgl from zgloszenia where id = p_zgloszenie_id;
        end if;
        return l_zgl;
    exception
        when no_data_found then
            raise_application_error(e_brak_obiektu,
                'Nie znaleziono zgłoszenia o ID ' || p_zgloszenie_id || '.');
    end pobierz_zgloszenie;

    -- Sprawdza, czy użytkownik o danej roli może zmienić status zgłoszenia.
    -- Nie zgłasza błędu: zwraca kod i komunikat (null = wolno).
    procedure sprawdz_zmiane_statusu (
        p_zgl            in  zgloszenia%rowtype,
        p_nowy_status    in  zgloszenia.status%type,
        p_uzytkownik_id  in  uzytkownicy.id%type,
        p_rola           in  uzytkownicy.rola%type,
        o_kod            out pls_integer,
        o_komunikat      out varchar2
    )
    is
    begin
        o_kod := null;
        o_komunikat := null;

        if p_zgl.status = c_zamkniete then
            o_kod := e_zamkniete;
            o_komunikat := 'Zgłoszenie ' || p_zgl.numer || ' jest zamknięte.';
        elsif czy_dozwolone_przejscie(p_zgl.status, p_nowy_status) = 'N' then
            o_kod := e_niedozwolone_przejscie;
            o_komunikat := 'Niedozwolona zmiana statusu: ' || p_zgl.status || ' -> ' || p_nowy_status || '.';
        elsif not czy_service_desk(p_rola) then
            -- Zgłaszający może tylko potwierdzić rozwiązanie albo otworzyć ponownie własne zgłoszenie.
            if p_zgl.zglaszajacy_id <> p_uzytkownik_id
               or p_zgl.status <> c_rozwiazane
               or p_nowy_status not in (c_zamkniete, c_w_toku)
            then
                o_kod := e_brak_uprawnien;
                o_komunikat := 'Brak uprawnień do zmiany statusu zgłoszenia ' || p_zgl.numer || '.';
            end if;
        elsif p_nowy_status = c_w_toku and p_zgl.przypisany_id is null then
            o_kod := e_brak_przypisania;
            o_komunikat := 'Zgłoszenie ' || p_zgl.numer || ' musi mieć przypisaną osobę, zanim przejdzie do realizacji.';
        end if;
    end sprawdz_zmiane_statusu;

    ----------------------------------------------------------------------------
    -- Funkcje publiczne
    ----------------------------------------------------------------------------

    function czy_dozwolone_przejscie (
        p_z_statusu   in zgloszenia.status%type,
        p_na_status   in zgloszenia.status%type
    ) return varchar2
    is
    begin
        return case
                   when p_z_statusu = c_nowe       and p_na_status = c_w_toku                         then 'T'
                   when p_z_statusu = c_w_toku     and p_na_status in (c_oczekuje, c_rozwiazane)       then 'T'
                   when p_z_statusu = c_oczekuje   and p_na_status = c_w_toku                         then 'T'
                   when p_z_statusu = c_rozwiazane and p_na_status in (c_zamkniete, c_w_toku)          then 'T'
                   else 'N'
               end;
    end czy_dozwolone_przejscie;

    function czy_moze_zmienic_status (
        p_zgloszenie_id  in zgloszenia.id%type,
        p_nowy_status    in zgloszenia.status%type,
        p_uzytkownik_id  in uzytkownicy.id%type
    ) return varchar2
    is
        l_kod        pls_integer;
        l_komunikat  varchar2(4000);
    begin
        sprawdz_zmiane_statusu(
            p_zgl           => pobierz_zgloszenie(p_zgloszenie_id),
            p_nowy_status   => p_nowy_status,
            p_uzytkownik_id => p_uzytkownik_id,
            p_rola          => rola_uzytkownika(p_uzytkownik_id),
            o_kod           => l_kod,
            o_komunikat     => l_komunikat);
        return case when l_kod is null then 'T' else 'N' end;
    exception
        when others then
            return 'N';
    end czy_moze_zmienic_status;

    function utworz (
        p_tytul           in zgloszenia.tytul%type,
        p_opis            in zgloszenia.opis%type,
        p_kategoria_id    in zgloszenia.kategoria_id%type,
        p_zglaszajacy_id  in zgloszenia.zglaszajacy_id%type
    ) return zgloszenia.id%type
    is
        l_rola      uzytkownicy.rola%type;
        l_aktywna   kategorie.aktywna%type;
        l_id        zgloszenia.id%type;
    begin
        l_rola := rola_uzytkownika(p_zglaszajacy_id);  -- sprawdza, czy użytkownik istnieje i jest aktywny

        begin
            select k.aktywna into l_aktywna from kategorie k where k.id = p_kategoria_id;
        exception
            when no_data_found then
                raise_application_error(e_brak_obiektu,
                    'Nie znaleziono kategorii o ID ' || p_kategoria_id || '.');
        end;

        if l_aktywna <> 'T' then
            raise_application_error(e_brak_obiektu, 'Kategoria o ID ' || p_kategoria_id || ' jest nieaktywna.');
        end if;

        insert into zgloszenia (tytul, opis, kategoria_id, zglaszajacy_id, status)
        values (p_tytul, p_opis, p_kategoria_id, p_zglaszajacy_id, c_nowe)
        returning id into l_id;

        return l_id;
    end utworz;

    procedure przypisz (
        p_zgloszenie_id  in zgloszenia.id%type,
        p_przypisany_id  in zgloszenia.przypisany_id%type,
        p_uzytkownik_id  in uzytkownicy.id%type
    )
    is
        l_zgl zgloszenia%rowtype;
    begin
        if not czy_service_desk(rola_uzytkownika(p_uzytkownik_id)) then
            raise_application_error(e_brak_uprawnien, 'Tylko service desk może przypisywać zgłoszenia.');
        end if;

        if not czy_service_desk(rola_uzytkownika(p_przypisany_id)) then
            raise_application_error(e_brak_uprawnien,
                'Zgłoszenie można przypisać tylko pracownikowi service desku.');
        end if;

        l_zgl := pobierz_zgloszenie(p_zgloszenie_id, p_zablokuj => true);

        if l_zgl.status = c_zamkniete then
            raise_application_error(e_zamkniete, 'Zgłoszenie ' || l_zgl.numer || ' jest zamknięte.');
        end if;

        update zgloszenia
           set przypisany_id = p_przypisany_id
         where id = p_zgloszenie_id;
    end przypisz;

    procedure zmien_status (
        p_zgloszenie_id  in zgloszenia.id%type,
        p_nowy_status    in zgloszenia.status%type,
        p_uzytkownik_id  in uzytkownicy.id%type
    )
    is
        l_zgl        zgloszenia%rowtype;
        l_kod        pls_integer;
        l_komunikat  varchar2(4000);
    begin
        l_zgl := pobierz_zgloszenie(p_zgloszenie_id, p_zablokuj => true);

        sprawdz_zmiane_statusu(
            p_zgl           => l_zgl,
            p_nowy_status   => p_nowy_status,
            p_uzytkownik_id => p_uzytkownik_id,
            p_rola          => rola_uzytkownika(p_uzytkownik_id),
            o_kod           => l_kod,
            o_komunikat     => l_komunikat);

        if l_kod is not null then
            raise_application_error(l_kod, l_komunikat);
        end if;

        update zgloszenia
           set status     = p_nowy_status,
               rozwiazano = case
                                when p_nowy_status = c_rozwiazane then sysdate
                                when p_nowy_status = c_w_toku     then null   -- ponowne otwarcie
                                else rozwiazano
                            end
         where id = p_zgloszenie_id;
    end zmien_status;

    procedure dodaj_komentarz (
        p_zgloszenie_id  in zgloszenia.id%type,
        p_autor_id       in uzytkownicy.id%type,
        p_tresc          in komentarze.tresc%type,
        p_wewnetrzny     in komentarze.wewnetrzny%type default 'N'
    )
    is
        l_rola  uzytkownicy.rola%type;
        l_zgl   zgloszenia%rowtype;
    begin
        l_rola := rola_uzytkownika(p_autor_id);
        l_zgl  := pobierz_zgloszenie(p_zgloszenie_id, p_zablokuj => true);

        if l_zgl.status = c_zamkniete then
            raise_application_error(e_zamkniete, 'Zgłoszenie ' || l_zgl.numer || ' jest zamknięte.');
        end if;

        if not czy_service_desk(l_rola) then
            if l_zgl.zglaszajacy_id <> p_autor_id then
                raise_application_error(e_brak_uprawnien,
                    'Można komentować tylko własne zgłoszenia.');
            end if;
            if p_wewnetrzny = 'T' then
                raise_application_error(e_brak_uprawnien,
                    'Komentarze wewnętrzne może dodawać tylko service desk.');
            end if;
        end if;

        insert into komentarze (zgloszenie_id, autor_id, tresc, wewnetrzny)
        values (p_zgloszenie_id, p_autor_id, p_tresc, nvl(p_wewnetrzny, 'N'));

        -- Odpowiedź zgłaszającego wznawia pracę nad zgłoszeniem.
        if l_zgl.status = c_oczekuje and p_autor_id = l_zgl.zglaszajacy_id then
            update zgloszenia set status = c_w_toku where id = p_zgloszenie_id;
        end if;
    end dodaj_komentarz;

end pkg_zgloszenia;
--rollback drop package body pkg_zgloszenia;
