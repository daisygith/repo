--liquibase formatted sql

--changeset deskflow:demo-uzytkownicy context:demo
--comment: Dane demonstracyjne - tylko gdy wdrażamy z --contexts=demo (DEV). Bez prawdziwych osób.
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ZGLASZAJACY01',    'Zgłaszający 1',  'ZGLASZAJACY');
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ZGLASZAJACY02',    'Zgłaszający 2',  'ZGLASZAJACY');
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ZGLASZAJACY03',    'Zgłaszający 3',  'ZGLASZAJACY');
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ZGLASZAJACY04',    'Zgłaszający 4',  'ZGLASZAJACY');
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ZGLASZAJACY05',    'Zgłaszający 5',  'ZGLASZAJACY');
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ODBIERAJACY_SD01', 'Odbierający SD 1', 'ODBIERAJACY_SD');
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ODBIERAJACY_SD02', 'Odbierający SD 2', 'ODBIERAJACY_SD');
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ODBIERAJACY_SD03', 'Odbierający SD 3', 'ODBIERAJACY_SD');
insert into uzytkownicy (login, nazwa_wyswietlana, rola) values ('ADMIN01',          'Administrator',  'ADMIN');
--rollback delete from uzytkownicy where login like 'ZGLASZAJACY0_' or login like 'ODBIERAJACY_SD0_' or login = 'ADMIN01';

--changeset deskflow:demo-zgloszenia context:demo splitStatements:false
--comment: Ok. 20 zgłoszeń w różnych statusach, z komentarzami. Wstawiane bezpośrednio (z pominięciem pakietu), żeby ustawić historyczne daty.
declare
    procedure zgl (
        p_tytul        varchar2,
        p_opis         varchar2,
        p_kategoria    varchar2,
        p_zglaszajacy  varchar2,
        p_przypisany   varchar2,
        p_status       varchar2,
        p_dni_temu     number,
        p_godz_rozw    number default null,
        p_komentarze   sys.odcivarchar2list default sys.odcivarchar2list()
    )
    is
        l_id        number;
        l_utworzono date := trunc(sysdate) - p_dni_temu + 9/24;
        l_autor     varchar2(50);
        l_tresc     varchar2(4000);
        l_wewn      varchar2(1);
    begin
        insert into zgloszenia (tytul, opis, kategoria_id, zglaszajacy_id, przypisany_id,
                                status, utworzono, rozwiazano)
        values (p_tytul, p_opis,
                (select id from kategorie   where kod   = p_kategoria),
                (select id from uzytkownicy where login = p_zglaszajacy),
                (select id from uzytkownicy where login = p_przypisany),
                p_status, l_utworzono,
                case when p_godz_rozw is not null then l_utworzono + p_godz_rozw / 24 end)
        returning id into l_id;

        -- Komentarze w formacie 'LOGIN|T/N|treść'
        for i in 1 .. p_komentarze.count loop
            l_autor := regexp_substr(p_komentarze(i), '[^|]+', 1, 1);
            l_wewn  := regexp_substr(p_komentarze(i), '[^|]+', 1, 2);
            l_tresc := substr(p_komentarze(i), length(l_autor) + length(l_wewn) + 3);
            insert into komentarze (zgloszenie_id, autor_id, tresc, wewnetrzny, utworzono)
            values (l_id, (select id from uzytkownicy where login = l_autor), l_tresc, l_wewn,
                    l_utworzono + i / 24);
        end loop;
    end zgl;
begin
    -- NOWE (bez przypisania)
    zgl('Nie działa drukarka na 2 piętrze', 'Drukarka pokazuje błąd papieru, choć papier jest.', 'SPRZET', 'ZGLASZAJACY01', null, 'NOWE', 0);
    zgl('Prośba o dostęp do folderu działu', 'Potrzebuję dostępu do folderu sieciowego działu zakupów.', 'DOSTEP', 'ZGLASZAJACY02', null, 'NOWE', 0);
    zgl('Wolny internet w sali konferencyjnej', 'Połączenie zrywa się podczas spotkań online.', 'SIEC', 'ZGLASZAJACY03', null, 'NOWE', 1);
    zgl('Instalacja programu do PDF', 'Proszę o instalację programu do edycji plików PDF.', 'OPROGRAMOWANIE', 'ZGLASZAJACY04', null, 'NOWE', 1);

    -- NOWE (przypisane, praca jeszcze nie zaczęta)
    zgl('Monitor miga', 'Drugi monitor co kilka minut gaśnie na sekundę.', 'SPRZET', 'ZGLASZAJACY05', 'ODBIERAJACY_SD01', 'NOWE', 2);
    zgl('Brak dźwięku w słuchawkach', 'Słuchawki nie działają po aktualizacji systemu.', 'SPRZET', 'ZGLASZAJACY01', 'ODBIERAJACY_SD02', 'NOWE', 2);

    -- W_TOKU
    zgl('Nie mogę się zalogować do systemu faktur', 'Po wpisaniu hasła pojawia się komunikat o błędzie.', 'DOSTEP', 'ZGLASZAJACY02', 'ODBIERAJACY_SD02', 'W_TOKU', 3,
        p_komentarze => sys.odcivarchar2list(
            'ODBIERAJACY_SD02|N|Jaki dokładnie komunikat się pojawia?',
            'ZGLASZAJACY02|N|Konto zablokowane.',
            'ODBIERAJACY_SD02|T|3 błędne logowania, sprawdzam blokadę w AD.'));
    zgl('Excel zawiesza się przy otwieraniu raportu', 'Duży plik z raportem miesięcznym nie otwiera się.', 'OPROGRAMOWANIE', 'ZGLASZAJACY03', 'ODBIERAJACY_SD01', 'W_TOKU', 4);
    zgl('Nowy laptop dla nowej osoby w zespole', 'Nowa osoba zaczyna pracę w przyszłym tygodniu.', 'SPRZET', 'ZGLASZAJACY04', 'ODBIERAJACY_SD03', 'W_TOKU', 5,
        p_komentarze => sys.odcivarchar2list(
            'ODBIERAJACY_SD03|T|Laptop zamówiony, czekamy na dostawę.'));
    zgl('VPN rozłącza się co godzinę', 'Praca zdalna jest przez to bardzo uciążliwa.', 'SIEC', 'ZGLASZAJACY05', 'ADMIN01', 'W_TOKU', 6);

    -- OCZEKUJE (czekamy na zgłaszającego)
    zgl('Błąd przy wysyłce maili z aplikacji', 'Maile z potwierdzeniem zamówienia nie dochodzą.', 'OPROGRAMOWANIE', 'ZGLASZAJACY01', 'ODBIERAJACY_SD01', 'OCZEKUJE', 5,
        p_komentarze => sys.odcivarchar2list(
            'ODBIERAJACY_SD01|N|Proszę o numer zamówienia, którego dotyczy problem.'));
    zgl('Uprawnienia do raportów sprzedaży', 'Nie widzę nowych raportów sprzedaży.', 'DOSTEP', 'ZGLASZAJACY03', 'ODBIERAJACY_SD02', 'OCZEKUJE', 7,
        p_komentarze => sys.odcivarchar2list(
            'ODBIERAJACY_SD02|N|Potrzebna akceptacja przełożonego - proszę o przesłanie.'));

    -- ROZWIAZANE (czekają na potwierdzenie)
    zgl('Klawiatura nie działa', 'Niektóre klawisze nie reagują.', 'SPRZET', 'ZGLASZAJACY02', 'ODBIERAJACY_SD03', 'ROZWIAZANE', 8, p_godz_rozw => 3,
        p_komentarze => sys.odcivarchar2list(
            'ODBIERAJACY_SD03|N|Wymieniona na nową, proszę o potwierdzenie.'));
    zgl('Reset hasła do poczty', 'Zapomniałem hasła.', 'DOSTEP', 'ZGLASZAJACY04', 'ODBIERAJACY_SD01', 'ROZWIAZANE', 9, p_godz_rozw => 1);
    zgl('Brak dostępu do Wi-Fi dla gości', 'Goście nie mogą się połączyć.', 'SIEC', 'ZGLASZAJACY05', 'ODBIERAJACY_SD02', 'ROZWIAZANE', 10, p_godz_rozw => 26);

    -- ZAMKNIETE
    zgl('Wymiana tonera', 'Toner się kończy.', 'SPRZET', 'ZGLASZAJACY01', 'ODBIERAJACY_SD03', 'ZAMKNIETE', 20, p_godz_rozw => 2);
    zgl('Instalacja przeglądarki', 'Proszę o instalację drugiej przeglądarki.', 'OPROGRAMOWANIE', 'ZGLASZAJACY02', 'ODBIERAJACY_SD01', 'ZAMKNIETE', 18, p_godz_rozw => 5);
    zgl('Konto dla stażysty', 'Nowy stażysta potrzebuje konta.', 'DOSTEP', 'ZGLASZAJACY03', 'ADMIN01', 'ZAMKNIETE', 15, p_godz_rozw => 30,
        p_komentarze => sys.odcivarchar2list(
            'ADMIN01|N|Konto założone, dane przekazane przełożonemu.',
            'ZGLASZAJACY03|N|Dziękuję, działa.'));
    zgl('Kabel sieciowy uszkodzony', 'Brak sieci przy biurku.', 'SIEC', 'ZGLASZAJACY04', 'ODBIERAJACY_SD02', 'ZAMKNIETE', 12, p_godz_rozw => 4);
    zgl('Pytanie o licencję', 'Czy mamy licencję na program do grafiki?', 'INNE', 'ZGLASZAJACY05', 'ODBIERAJACY_SD01', 'ZAMKNIETE', 11, p_godz_rozw => 48);
end;
--rollback delete from komentarze where zgloszenie_id in (select z.id from zgloszenia z join uzytkownicy u on u.id = z.zglaszajacy_id where u.login like 'ZGLASZAJACY0_');
--rollback delete from zgloszenia where zglaszajacy_id in (select id from uzytkownicy where login like 'ZGLASZAJACY0_');
