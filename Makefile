ifneq (,$(wildcard ./.env))
    include .env
    export
endif

ENV_VARS = DATABASE_URL=$(GOOSE_DBSTRING) PORT=$(PORT) SECRET_KEY_BASE=$(SECRET_KEY_BASE) JWT_SECRET=$(JWT_SECRET) CERTIFICATE_PATH=$(CERTIFICATE_PATH) KEYFILE_PATH=$(KEYFILE_PATH)

squirel:
	$(ENV_VARS) MODE="PACKAGE" gleam run -m squirrel

start:
	$(ENV_VARS) MODE="MAIN" gleam run

tests:
	$(ENV_VARS) MODE="TEST" gleam test
