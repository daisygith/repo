--liquibase formatted sql

--changeset deskflow:slownik-kategorie
--comment: Dane słownikowe - trafiają na każde środowisko (DEV, TEST, PROD)
insert into kategorie (kod, nazwa) values ('SPRZET',        'Sprzęt');
insert into kategorie (kod, nazwa) values ('OPROGRAMOWANIE', 'Oprogramowanie');
insert into kategorie (kod, nazwa) values ('DOSTEP',        'Dostęp i konta');
insert into kategorie (kod, nazwa) values ('SIEC',          'Sieć');
insert into kategorie (kod, nazwa) values ('INNE',          'Inne');
--rollback delete from kategorie where kod in ('SPRZET', 'OPROGRAMOWANIE', 'DOSTEP', 'SIEC', 'INNE');
