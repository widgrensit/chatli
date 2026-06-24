-module(chat).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0]).

table() -> ~"chat".

fields() -> [
    #kura_field{name = id, type = uuid, primary_key = true},
    #kura_field{name = name, type = string, nullable = false},
    #kura_field{name = description, type = string},
    #kura_field{name = type, type = string}
].
