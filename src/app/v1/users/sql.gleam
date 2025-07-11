import gleam/dynamic/decode
import pog

/// A row you get from running the `create_user` query
/// defined in `./src/app/v1/users/sql/create_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.0.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateUserRow {
  CreateUserRow(id: Int, username: String)
}

/// Runs the `create_user` query
/// defined in `./src/app/v1/users/sql/create_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.0.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(db, arg_1, arg_2) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use username <- decode.field(1, decode.string)
    decode.success(CreateUserRow(id:, username:))
  }

  "insert into users (username, password_hash)
values ($1, $2)
returning id, username;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
