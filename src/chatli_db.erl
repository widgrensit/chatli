-module(chatli_db).

-export([
    create_message/1,
    get_message/2,
    get_chat_messages/1,
    create_chat/1,
    get_chat/1,
    get_all_chats/1,
    get_filtered_messages/2,
    get_dm_chat/2,
    delete_chat/1,
    add_participant/2,
    remove_participant/2,
    get_participants/1,
    get_all_other_participants/2,
    create_callback/3,
    get_callback/1,
    get_user_callbacks/1,
    delete_callback/1,
    create_attachment/4,
    get_attachment/2
]).

-include_lib("kura/include/kura.hrl").

%% Messages

create_message(Params) ->
    CS = kura_changeset:cast(message, #{}, encode_payload(Params), [
        id, chat_id, payload, sender, timestamp, type, action, sender_info
    ]),
    case chatli_repo:insert(CS) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

%% A text payload is a JSON string scalar; kura casts jsonb binaries as
%% JSON text, so encode it before the changeset.
encode_payload(#{<<"payload">> := P} = Params) when is_binary(P) ->
    Params#{<<"payload">> := iolist_to_binary(json:encode(P))};
encode_payload(Params) ->
    Params.

get_message(ChatId, MessageId) ->
    Q = kura_query:from(message),
    Q1 = kura_query:select(Q, [id, chat_id, payload, sender, sender_info, timestamp]),
    Q2 = kura_query:where(Q1, {chat_id, ChatId}),
    Q3 = kura_query:where(Q2, {id, MessageId}),
    one(Q3).

get_chat_messages(ChatId) ->
    Q = kura_query:from(message),
    Q1 = kura_query:select(Q, [id, chat_id, payload, sender, sender_info, timestamp]),
    Q2 = kura_query:where(Q1, {chat_id, ChatId}),
    Q3 = kura_query:order_by(Q2, [{timestamp, asc}]),
    chatli_repo:all(Q3).

get_filtered_messages(ChatId, QS) ->
    Q = kura_query:from(message),
    Q1 = kura_query:select(Q, [id, chat_id, payload, sender, sender_info, timestamp]),
    Q2 = kura_query:where(Q1, {chat_id, ChatId}),
    Q3 = maybe_after(Q2, QS),
    Q4 = maybe_before(Q3, QS),
    Q5 = kura_query:order_by(Q4, [{timestamp, asc}]),
    chatli_repo:all(Q5).

maybe_after(Q, #{<<"after">> := After}) ->
    kura_query:where(Q, {timestamp, '>=', binary_to_integer(After)});
maybe_after(Q, _) ->
    Q.

maybe_before(Q, #{<<"before">> := Before}) ->
    kura_query:where(Q, {timestamp, '<=', binary_to_integer(Before)});
maybe_before(Q, _) ->
    Q.

%% Chats

create_chat(Params) ->
    CS = kura_changeset:cast(chat, #{}, Params, [id, name, description, type]),
    case chatli_repo:insert(CS) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

get_chat(ChatId) ->
    case chatli_repo:get(chat, ChatId) of
        {ok, Chat} -> {ok, Chat};
        {error, not_found} -> undefined
    end.

get_dm_chat(User1, User2) ->
    SQL =
        <<"SELECT chat.*"
          " FROM chat"
          " INNER JOIN participant AS p1 ON p1.user_id = $1 AND p1.chat_id = chat.id"
          " INNER JOIN participant AS p2 ON p2.user_id = $2 AND p2.chat_id = chat.id"
          " WHERE chat.type = '1to1' LIMIT 1">>,
    case chatli_repo:query(SQL, [User1, User2]) of
        {ok, [Row | _]} -> {ok, Row};
        {ok, []} -> undefined;
        {error, _} = Error -> Error
    end.

get_all_chats(UserId) ->
    SQL =
        <<"SELECT chat.*"
          " FROM chat"
          " INNER JOIN participant ON participant.user_id = $1 AND participant.chat_id = chat.id">>,
    chatli_repo:query(SQL, [UserId]).

delete_chat(ChatId) ->
    Q = kura_query:from(chat),
    Q1 = kura_query:where(Q, {id, ChatId}),
    case chatli_repo:delete_all(Q1) of
        {ok, 1} -> ok;
        {ok, 0} -> undefined;
        {error, _} = Error -> Error
    end.

%% Participants

add_participant(ChatId, UserId) ->
    CS = kura_changeset:cast(participant, #{}, #{<<"chat_id">> => ChatId, <<"user_id">> => UserId}, [chat_id, user_id]),
    case chatli_repo:insert(CS) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

remove_participant(ChatId, UserId) ->
    Q = kura_query:from(participant),
    Q1 = kura_query:where(Q, {chat_id, ChatId}),
    Q2 = kura_query:where(Q1, {user_id, UserId}),
    case chatli_repo:delete_all(Q2) of
        {ok, 1} -> ok;
        {ok, 0} -> undefined;
        {error, _} = Error -> Error
    end.

get_participants(ChatId) ->
    Q = kura_query:from(participant),
    Q1 = kura_query:select(Q, [user_id]),
    Q2 = kura_query:where(Q1, {chat_id, ChatId}),
    chatli_repo:all(Q2).

get_all_other_participants(ChatId, UserId) ->
    SQL =
        <<"SELECT chatli_user.id, chatli_user.username, chatli_user.email"
          " FROM participant"
          " INNER JOIN chatli_user ON chatli_user.id = participant.user_id"
          " WHERE participant.chat_id = $1 AND participant.user_id != $2">>,
    chatli_repo:query(SQL, [ChatId, UserId]).

%% Callbacks

create_callback(CallbackId, UserId, Url) ->
    CS = kura_changeset:cast(callback, #{}, #{<<"id">> => CallbackId, <<"user_id">> => UserId, <<"url">> => Url}, [id, user_id, url]),
    case chatli_repo:insert(CS) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

get_callback(CallbackId) ->
    case chatli_repo:get(callback, CallbackId) of
        {ok, Result} -> {ok, Result};
        {error, not_found} -> undefined
    end.

get_user_callbacks(UserId) ->
    Q = kura_query:from(callback),
    Q1 = kura_query:select(Q, [url]),
    Q2 = kura_query:where(Q1, {user_id, UserId}),
    chatli_repo:all(Q2).

delete_callback(CallbackId) ->
    Q = kura_query:from(callback),
    Q1 = kura_query:where(Q, {id, CallbackId}),
    case chatli_repo:delete_all(Q1) of
        {ok, 1} -> ok;
        {ok, 0} -> undefined;
        {error, _} = Error -> Error
    end.

%% Attachments

create_attachment(AttachmentId, ChatId, Mime, ByteSize) ->
    CS = kura_changeset:cast(attachment, #{}, #{
        <<"id">> => AttachmentId,
        <<"chat_id">> => ChatId,
        <<"mime">> => Mime,
        <<"length">> => ByteSize
    }, [id, chat_id, mime, length]),
    case chatli_repo:insert(CS) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

get_attachment(AttachmentId, ChatId) ->
    Q = kura_query:from(attachment),
    Q1 = kura_query:where(Q, {id, AttachmentId}),
    Q2 = kura_query:where(Q1, {chat_id, ChatId}),
    one(Q2).

%% Internal

one(Q) ->
    case chatli_repo:one(Q) of
        {ok, Row} -> {ok, Row};
        {error, not_found} -> undefined;
        {error, _} = Error -> Error
    end.
