# Koe (声)

A checklist for building a real-time chat application with Gleam, OTP, and PostgreSQL.

---

### Phase 1: Environment & Basic Server

- [x] **Set up the Docker environment.**
  - Create a `Dockerfile` for a multi-stage build of the Gleam application.
  - Create a `docker-compose.yml` to run the Gleam app service and a `postgresql` service.

- [x] **Implement a basic Wisp web server.**
  - Serve a health check endpoint to verify the server is running correctly.
  - **Endpoint:** `GET /api/v1/health`
  - **Success Response (`200 OK`):** `{"status": "ok"}`

---

### Phase 2: User Accounts & Authentication

- [ ] **Define the database schema and implement registration.**
  - Create a SQL migration file for the `users` table (`id`, `username`, `password_hash`).
  - Implement the user registration endpoint.
  - **Endpoint:** `POST /api/v1/register`
  - **Request Body:** `{"username": "new_user", "password": "a_strong_password"}`
  - **Success Response (`201 Created`):** `{"message": "User created successfully"}`
  - **Error Response (`409 Conflict`):** `{"error": "Username already taken"}`

- [ ] **Implement cookie-based authentication.**
  - Implement the login endpoint, which sets a secure `HttpOnly` cookie on success.
  - **Endpoint:** `POST /api/v1/login`
  - **Request Body:** `{"username": "gleam_fan", "password": "my_secure_password"}`
  - **Success Response (`200 OK`):**
    - **Headers:** `Set-Cookie: auth_token=...; HttpOnly; Secure; SameSite=Strict; Path=/`
    - **Body:** `{"message": "Login successful"}`
  - **Error Response (`401 Unauthorized`):** `{"error": "Invalid username or password"}`

- [ ] **Implement the logout endpoint.**
  - The endpoint should clear the `auth_token` cookie.
  - **Endpoint:** `POST /api/v1/logout`
  - **Success Response (`200 OK`):**
    - **Headers:** `Set-Cookie: auth_token=; HttpOnly; ...; Max-Age=0`
    - **Body:** `{"message": "Logged out successfully"}`

---

### Phase 3: Core Chat Logic & API

- [ ] **Define the OTP actors for stateful chat logic.**
  - Create a `RoomActor` to manage the state of a single chat room (i.e., its list of connected clients).
  - Create a `ConnectionActor` to manage the lifecycle of a single WebSocket connection.
  - Design a supervision tree to ensure rooms are fault-tolerant.

- [ ] **Implement the supporting REST API for rooms.**
  - Create an endpoint to list available chat rooms.
  - **Endpoint:** `GET /api/v1/rooms`
  - **Success Response (`200 OK`):**
    ```json
    [
      { "id": "general", "name": "General Chat" },
      { "id": "gleam-dev", "name": "Gleam Development" }
    ]
    ```

---

### Phase 4: Real-Time WebSocket Integration

- [ ] **Implement the WebSocket connection endpoint.**
  - The handler must validate the `auth_token` cookie from the HTTP upgrade request.
  - On success, a `ConnectionActor` is spawned and registered with the appropriate `RoomActor`.
  - **Endpoint:** `GET /ws/v1/chat/{room_id}`
  - **Failure Response:** `401 Unauthorized` (if cookie is invalid or missing).

- [ ] **Implement the real-time messaging protocol.**
  - Handle incoming messages from clients and broadcast them to the room.

  #### Client-to-Server Events
  - **Event:** `send_message`
  - **Payload:** `{"text": "Hello, Gleam!"}`

  #### Server-to-Client Events
  - **Event:** `new_message`
  - **Payload:** `{"username": "gleam_fan", "text": "Hello, Gleam!", "timestamp": "..."}`

  - **Event:** `user_joined_room`
  - **Payload:** `{"username": "new_user", "online_users": ["gleam_fan", "new_user"]}`

  - **Event:** `user_left_room`
  - **Payload:** `{"username": "new_user", "online_users": ["gleam_fan"]}`
