import gleam/erlang/process.{type Name}
import gleam/result
import pog

pub fn from_name(name: Name(pog.Message)) -> pog.Connection {
  pog.named_connection(name)
}

pub fn mock_connection() -> pog.Connection {
  pog.named_connection(process.new_name("postgresql"))
}

pub fn parse_database_uri(
  name: Name(pog.Message),
  database_url: String,
) -> Result(pog.Config, String) {
  pog.url_config(name, database_url)
  |> result.replace_error("database url is not valid")
}
