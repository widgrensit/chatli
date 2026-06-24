-module(participant).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0]).

table() -> ~"participant".

fields() -> [
    #kura_field{name = id, type = id, primary_key = true},
    #kura_field{name = chat_id, type = uuid},
    #kura_field{name = user_id, type = uuid}
].
