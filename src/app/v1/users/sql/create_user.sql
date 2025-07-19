insert into
users (username, password_hash)
values ($1, $2)
returning id, username;
