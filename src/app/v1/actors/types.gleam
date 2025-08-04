import gleam/erlang/process.{type Subject}

pub type ManagerMessage {
  GetOrCreateRoom(
    reply_with: Subject(Result(Subject(RoomMessage), ManagerError)),
    name: String,
  )
  ReleaseRoom(name: String)
  GetRooms(reply_with: Subject(List(String)))
}

pub type ManagerError {
  NoAvailableRooms
}

pub type Connection {
  Connection(pid: process.Pid, reply_with: Subject(Incoming), user: String)
}

pub type Incoming {
  UserJoined(username: String, connected: List(String))
  UserLeft(username: String, connected: List(String))
  MessageSent(username: String, message: String)
}

pub type RoomMessage {
  Assign(name: String)
  Reset
  Join(conn: Connection)
  Leave(conn: Connection)
  Message(conn: Connection, message: String)
}
