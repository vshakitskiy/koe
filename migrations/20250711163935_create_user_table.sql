-- +goose Up
-- +goose StatementBegin
create table users (
    id serial primary key,
    username varchar(255) not null unique,
    password_hash text not null
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
drop table users;
-- +goose StatementEnd
