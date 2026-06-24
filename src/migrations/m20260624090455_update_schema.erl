-module(m20260624090455_update_schema).
-behaviour(kura_migration).
-include_lib("kura/include/kura.hrl").
-export([up/0, down/0]).

up() ->
    [{create_table, <<"attachment">>, [
        #kura_column{name = id, type = uuid, primary_key = true},
        #kura_column{name = chat_id, type = uuid, nullable = false},
        #kura_column{name = mime, type = string, nullable = false},
        #kura_column{name = length, type = integer}
    ]},
     {create_table, <<"callback">>, [
        #kura_column{name = id, type = uuid, primary_key = true},
        #kura_column{name = user_id, type = uuid, nullable = false},
        #kura_column{name = url, type = string, nullable = false}
    ]},
     {create_table, <<"chat">>, [
        #kura_column{name = id, type = uuid, primary_key = true},
        #kura_column{name = name, type = string, nullable = false},
        #kura_column{name = description, type = string},
        #kura_column{name = type, type = string}
    ]},
     {create_table, <<"chatli_user">>, [
        #kura_column{name = id, type = uuid, primary_key = true},
        #kura_column{name = username, type = string, nullable = false},
        #kura_column{name = phone_number, type = string},
        #kura_column{name = email, type = string},
        #kura_column{name = avatar, type = string},
        #kura_column{name = password, type = string, nullable = false}
    ]},
     {create_table, <<"device">>, [
        #kura_column{name = id, type = uuid, primary_key = true},
        #kura_column{name = user_id, type = uuid, nullable = false},
        #kura_column{name = name, type = string}
    ]},
     {create_table, <<"message">>, [
        #kura_column{name = id, type = uuid, primary_key = true},
        #kura_column{name = chat_id, type = uuid, nullable = false},
        #kura_column{name = payload, type = jsonb},
        #kura_column{name = sender, type = uuid, nullable = false},
        #kura_column{name = type, type = string},
        #kura_column{name = action, type = string},
        #kura_column{name = timestamp, type = integer},
        #kura_column{name = sender_info, type = jsonb}
    ]},
     {create_table, <<"participant">>, [
        #kura_column{name = id, type = id, primary_key = true},
        #kura_column{name = chat_id, type = uuid},
        #kura_column{name = user_id, type = uuid}
    ]}].

down() ->
    [{drop_table, <<"attachment">>},
     {drop_table, <<"callback">>},
     {drop_table, <<"chat">>},
     {drop_table, <<"chatli_user">>},
     {drop_table, <<"device">>},
     {drop_table, <<"message">>},
     {drop_table, <<"participant">>}].
