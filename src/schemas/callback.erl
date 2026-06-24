-module(callback).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0]).

table() -> ~"callback".

fields() -> [
    #kura_field{name = id, type = uuid, primary_key = true},
    #kura_field{name = user_id, type = uuid, nullable = false},
    #kura_field{name = url, type = string, nullable = false}
].
