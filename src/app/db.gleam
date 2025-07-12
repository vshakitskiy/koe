import envoy
import gleam/erlang/process.{type Name}
import gleam/result
import pog

pub fn process() -> Name(pog.Message) {
  process.new_name("postgresql")
}

pub fn connection() -> pog.Connection {
  pog.named_connection(process())
}

pub fn connection_pool(name: Name(pog.Message)) {
  use database_url <- result.try(envoy.get("DATABASE_URL"))
  use config <- result.try(pog.url_config(name, database_url))

  echo config

  Ok(pog.supervised(config))
}

pub fn parse_database_uri(name: Name(pog.Message)) {
  use database_url <- result.try(envoy.get("DATABASE_URL"))

  pog.url_config(name, database_url)
}
