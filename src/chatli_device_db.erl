-module(chatli_device_db).

-export([
    upsert/3,
    delete/2,
    get/2,
    get_all/1
]).

-include_lib("kura/include/kura.hrl").

upsert(DeviceId, UserId, Name) ->
    delete(DeviceId, UserId),
    CS = kura_changeset:cast(device, #{}, #{
        <<"id">> => DeviceId,
        <<"user_id">> => UserId,
        <<"name">> => Name
    }, [id, user_id, name]),
    case chatli_repo:insert(CS) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

delete(DeviceId, UserId) ->
    Q = kura_query:from(device),
    Q1 = kura_query:where(Q, {id, DeviceId}),
    Q2 = kura_query:where(Q1, {user_id, UserId}),
    chatli_repo:delete_all(Q2).

get(DeviceId, UserId) ->
    Q = kura_query:from(device),
    Q1 = kura_query:select(Q, [id, name]),
    Q2 = kura_query:where(Q1, {id, DeviceId}),
    Q3 = kura_query:where(Q2, {user_id, UserId}),
    case chatli_repo:one(Q3) of
        {ok, Row} -> {ok, Row};
        {error, not_found} -> undefined;
        {error, _} = Error -> Error
    end.

get_all(UserId) ->
    Q = kura_query:from(device),
    Q1 = kura_query:select(Q, [id, name]),
    Q2 = kura_query:where(Q1, {user_id, UserId}),
    chatli_repo:all(Q2).
