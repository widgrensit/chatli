-module(chatli_user_db).

-export([
    create/1,
    get/1,
    get_login/2,
    find/2,
    delete/1,
    get_all/0,
    get_all_other/1
]).

-include_lib("kura/include/kura.hrl").

create(Params) ->
    CS = kura_changeset:cast(chatli_user, #{}, Params, [id, username, phone_number, email, password]),
    case chatli_repo:insert(CS) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

get(UserId) ->
    Q = kura_query:from(chatli_user),
    Q1 = kura_query:select(Q, [id, username, phone_number, email]),
    Q2 = kura_query:where(Q1, {id, UserId}),
    case chatli_repo:one(Q2) of
        {ok, Row} -> {ok, Row};
        {error, not_found} -> undefined;
        {error, _} = Error -> Error
    end.

get_login(Username, Password) ->
    Q = kura_query:from(chatli_user),
    Q1 = kura_query:where(Q, {username, Username}),
    Q2 = kura_query:where(Q1, {password, Password}),
    case chatli_repo:one(Q2) of
        {ok, Row} -> {ok, Row};
        {error, not_found} -> undefined;
        {error, _} = Error -> Error
    end.

find(<<"email">>, Value) ->
    case chatli_repo:get_by(chatli_user, [{email, Value}]) of
        {ok, Row} -> {ok, Row};
        {error, not_found} -> undefined;
        {error, _} = Error -> Error
    end;
find(<<"phone_number">>, Value) ->
    case chatli_repo:get_by(chatli_user, [{phone_number, Value}]) of
        {ok, Row} -> {ok, Row};
        {error, not_found} -> undefined;
        {error, _} = Error -> Error
    end.

delete(UserId) ->
    Q = kura_query:from(chatli_user),
    Q1 = kura_query:where(Q, {id, UserId}),
    case chatli_repo:delete_all(Q1) of
        {ok, 1} -> ok;
        {ok, 0} -> undefined;
        {error, _} = Error -> Error
    end.

get_all() ->
    Q = kura_query:from(chatli_user),
    Q1 = kura_query:select(Q, [id, avatar, email, phone_number, username]),
    chatli_repo:all(Q1).

get_all_other(UserId) ->
    Q = kura_query:from(chatli_user),
    Q1 = kura_query:select(Q, [id, avatar, email, phone_number, username]),
    Q2 = kura_query:where(Q1, {id, '!=', UserId}),
    chatli_repo:all(Q2).
