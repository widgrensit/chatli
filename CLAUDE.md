# chatli

Erlang/OTP real-time chat backend built on the Nova web framework.

## Stack
- Erlang/OTP, Nova framework, Cowboy
- PostgreSQL via kura (kura_postgres backend)
- JWT auth via jwerl
- Erlydtl templates
- WebSocket for real-time delivery

## Build & run
```bash
rebar3 compile
rebar3 shell              # Dev with config/sys.config.local
rebar3 release            # Production release
```

## Test & quality
```bash
rebar3 ct                 # Common Test
rebar3 ci                 # compile, dialyzer, xref, fmt, lint
rebar3 fmt                # erlfmt
rebar3 lint               # rebar3_lint
```

## Configuration
- Port: 8090 (nova.cowboy_configuration.port)
- DB: PostgreSQL (host: db, port: 5432, user: postgres, pass: root)
- WebSocket idle timeout: 15s
- Attachments: ./priv/attachments/

## API routes
- `/v1/*` — public (signup, login, callbacks, history, heartbeat)
- `/client/*` — JWT-protected (messages, chats, participants, devices)
- `/client/device/:deviceid/user/:userid/ws` — WebSocket

## Structure
- `src/chatli_router.erl` — route definitions
- `src/chatli_db.erl` — database queries
- `src/chatli_auth.erl` — JWT auth
- `src/chatli_ws_srv.erl` — WebSocket server
- `src/chatli_ws_client.erl` — WebSocket client handler
- `src/controllers/` — HTTP endpoint handlers
- `src/plugins/` — Nova middleware
