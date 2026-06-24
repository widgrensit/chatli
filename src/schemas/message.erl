-module(message).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0]).

table() -> ~"message".

fields() -> [
    #kura_field{name = id, type = uuid, primary_key = true},
    #kura_field{name = chat_id, type = uuid, nullable = false},
    #kura_field{name = payload, type = jsonb},
    #kura_field{name = sender, type = uuid, nullable = false},
    #kura_field{name = type, type = string},
    #kura_field{name = action, type = string},
    #kura_field{name = timestamp, type = integer},
    #kura_field{name = sender_info, type = jsonb}
].
