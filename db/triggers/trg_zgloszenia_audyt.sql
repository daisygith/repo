--liquibase formatted sql

--changeset deskflow:trg_zgloszenia_audyt runOnChange:true splitStatements:false
--comment: Ustawia datę ostatniej modyfikacji zgłoszenia
create or replace trigger trg_zgloszenia_audyt
    before update on zgloszenia
    for each row
begin
    :new.zaktualizowano := sysdate;
end trg_zgloszenia_audyt;
--rollback drop trigger trg_zgloszenia_audyt;
