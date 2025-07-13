DATABASE_URL = postgres://admeanie:assword@localhost:5555/koe

squirrel:
	DATABASE_URL=$(DATABASE_URL) gleam run -m squirrel

run:
	DATABASE_URL=$(DATABASE_URL) gleam run

tests:
	DATABASE_URL=$(DATABASE_URL) gleam test
