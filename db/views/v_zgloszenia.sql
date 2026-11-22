--liquibase formatted sql

--changeset deskflow:v_zgloszenia runOnChange:true splitStatements:false
--comment: Zgłoszenia z nazwami kategorii i osób, pod raporty APEX
create or replace view v_zgloszenia as
select z.id,
       z.numer,
       z.tytul,
       z.opis,
       z.status,
       z.kategoria_id,
       k.kod                         as kategoria_kod,
       k.nazwa                       as kategoria,
       z.zglaszajacy_id,
       zg.login                      as zglaszajacy_login,
       zg.nazwa_wyswietlana          as zglaszajacy,
       z.przypisany_id,
       pr.login                      as przypisany_login,
       pr.nazwa_wyswietlana          as przypisany,
       z.utworzono,
       z.zaktualizowano,
       z.rozwiazano,
       round((z.rozwiazano - z.utworzono) * 24, 1) as czas_rozwiazania_godz,
       (select count(*)
          from komentarze c
         where c.zgloszenie_id = z.id) as liczba_komentarzy
  from zgloszenia  z
  join kategorie   k  on k.id  = z.kategoria_id
  join uzytkownicy zg on zg.id = z.zglaszajacy_id
  left join uzytkownicy pr on pr.id = z.przypisany_id
--rollback drop view v_zgloszenia;
