-module(attachment).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0]).

table() -> ~"attachment".

fields() -> [
    #kura_field{name = id, type = uuid, primary_key = true},
    #kura_field{name = chat_id, type = uuid, nullable = false},
    #kura_field{name = mime, type = string, nullable = false},
    #kura_field{name = length, type = integer}
].
