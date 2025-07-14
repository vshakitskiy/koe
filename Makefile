ifneq (,$(wildcard ./.env))
    include .env
    export
endif

squirrel:
	DATABASE_URL=$(GOOSE_DBSTRING) PORT=$(PORT) SECRET_KEY_BASE=$(SECRET_KEY_BASE) MODE="PACKAGE" gleam run -m squirrel

run:
	DATABASE_URL=$(GOOSE_DBSTRING) PORT=$(PORT) SECRET_KEY_BASE=$(SECRET_KEY_BASE) MODE="START" gleam run

tests:
	DATABASE_URL=$(GOOSE_DBSTRING) PORT=$(PORT) SECRET_KEY_BASE=$(SECRET_KEY_BASE) MODE="TEST" gleam test
