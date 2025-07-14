> [!NOTE]
> Work-in-progress toy project for understanding functional programming with Gleam and it's ecosystem.

# Koe (声)

A real-time chat application with Gleam, OTP, and PostgreSQL.

## Core Technologies

-   **Language:** Gleam
-   **Web Server:** Wisp (`wisp`)
-   **Concurrency:** Gleam OTP (`gleam_otp`) for stateful application logic.
-   **Database:** PostgreSQL
-   **DB Client:** Squirel (`squirel`)
-   **Environment:** Docker & Docker Compose
-   **Authentication:** Secure, `HttpOnly` cookies.

See [TODO.md](TODO.md) for more.

## Getting Started

To run the application locally, follow the guide:

1. Copy `.env.example` to `.env` and edit it to your liking.
2. Run `docker-compose up -d postgresql` to run the PostgreSQL database.
3. Use `make run` to start the application. This will pass all environment variables needed to the application.
4. Use `make test` to run the tests.
5. To regenerate sql queries, run `make squirrel`.
