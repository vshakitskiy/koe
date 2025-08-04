import app/v1/actors/types.{type ManagerMessage, type RoomMessage}
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/otp/supervision

pub type Manager {
  Manager(
    available: List(Subject(RoomMessage)),
    active: dict.Dict(String, Subject(RoomMessage)),
  )
}

pub fn start(
  name: process.Name(ManagerMessage),
  pool: List(Subject(RoomMessage)),
) {
  actor.new(Manager(available: pool, active: dict.new()))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start()
}

pub fn supervised(
  name: process.Name(ManagerMessage),
  pool: List(Subject(RoomMessage)),
) {
  supervision.supervisor(fn() { start(name, pool) })
}

pub fn get_or_create_room(manager: Subject(ManagerMessage), name: String) {
  actor.call(manager, 1000, types.GetOrCreateRoom(_, name))
}

pub fn release_room(manager: Subject(ManagerMessage), name: String) {
  actor.send(manager, types.ReleaseRoom(name))
}

pub fn get_rooms(manager: Subject(ManagerMessage)) {
  actor.call(manager, 1000, types.GetRooms)
}

fn handle_message(state: Manager, message: ManagerMessage) {
  case message {
    types.GetOrCreateRoom(reply_with:, name:) -> {
      case dict.get(state.active, name) {
        Ok(subject) -> {
          actor.send(reply_with, Ok(subject))
          actor.continue(state)
        }
        Error(Nil) -> {
          case state.available {
            [] -> {
              actor.send(reply_with, Error(types.NoAvailableRooms))
              actor.continue(state)
            }
            [subject, ..rest] -> {
              actor.send(reply_with, Ok(subject))
              actor.send(subject, types.Assign(name))
              actor.continue(Manager(
                available: rest,
                active: dict.insert(state.active, name, subject),
              ))
            }
          }
        }
      }
    }

    types.ReleaseRoom(name) -> {
      case dict.get(state.active, name) {
        Ok(subject) -> {
          actor.send(subject, types.Reset)
          actor.continue(Manager(
            available: [subject, ..state.available],
            active: dict.drop(state.active, [name]),
          ))
        }
        Error(Nil) -> {
          actor.continue(state)
        }
      }
    }

    types.GetRooms(reply_with) -> {
      actor.send(reply_with, dict.keys(state.active))
      actor.continue(state)
    }
  }
}
