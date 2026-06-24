-module(chatli_user).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0]).

table() -> ~"chatli_user".

fields() -> [
    #kura_field{name = id, type = uuid, primary_key = true},
    #kura_field{name = username, type = string, nullable = false},
    #kura_field{name = phone_number, type = string},
    #kura_field{name = email, type = string},
    #kura_field{name = avatar, type = string},
    #kura_field{name = password, type = string, nullable = false}
].
