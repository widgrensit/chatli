-module(m20260911065748_alter_message).
-moduledoc false.
-behaviour(kura_migration).
-include_lib("kura/include/kura.hrl").
-export([up/0, down/0, safe/0]).

-spec up() -> [kura_migration:operation()].
up() ->
    [{alter_table, ~"message", [
        {modify_column, timestamp, bigint}
    ]}].

-spec down() -> [kura_migration:operation()].
down() ->
    [{alter_table, ~"message", [
        {modify_column, timestamp, integer}
    ]}].

-spec safe() -> [kura_migration:safe_entry()].
safe() ->
    [{modify_column, timestamp}].
