//// This module contains the code to run the sql queries defined in
//// `./src/app/v1/users/sql`.
//// > 🐿️ This module was generated automatically using v4.2.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import pog

/// A row you get from running the `create_user` query
/// defined in `./src/app/v1/users/sql/create_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateUserRow {
  CreateUserRow(id: Int, username: String)
}

/// Runs the `create_user` query
/// defined in `./src/app/v1/users/sql/create_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(db, arg_1, arg_2) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use username <- decode.field(1, decode.string)
    decode.success(CreateUserRow(id:, username:))
  }

  "insert into
users (username, password_hash)
values ($1, $2)
returning id, username;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_user_by_username` query
/// defined in `./src/app/v1/users/sql/delete_user_by_username.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_user_by_username(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "delete
from users
where username = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_user_by_id` query
/// defined in `./src/app/v1/users/sql/find_user_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByIdRow {
  FindUserByIdRow(id: Int, username: String, password_hash: String)
}

/// Runs the `find_user_by_id` query
/// defined in `./src/app/v1/users/sql/find_user_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_id(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use username <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(FindUserByIdRow(id:, username:, password_hash:))
  }

  "select id, username, password_hash
from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_user_by_username` query
/// defined in `./src/app/v1/users/sql/find_user_by_username.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByUsernameRow {
  FindUserByUsernameRow(id: Int, username: String, password_hash: String)
}

/// Runs the `find_user_by_username` query
/// defined in `./src/app/v1/users/sql/find_user_by_username.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_username(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use username <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(FindUserByUsernameRow(id:, username:, password_hash:))
  }

  "select id, username, password_hash
from users
where username = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
