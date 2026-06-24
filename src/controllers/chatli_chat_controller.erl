-module(chatli_chat_controller).
-export([
    message/1,
    get_archive/1,
    manage_message/1,
    get_chats/1,
    get_chat/1,
    delete_chat/1,
    create_chat/1,
    participants/1,
    manage_participants/1,
    get_attachment/1,
    get_attachment_no_auth/1,
    get_history/1
]).

message(#{
    headers := #{<<"user-agent">> := UserAgent},
    auth_data := #{id := Sender},
    multipart_data := FormData
}) ->
    Id = chatli_uuid:get_v4(),
    case FormData of
        [] ->
            {status, 200};
        FormData ->
            ChatId = proplists:get_value(<<"chat_id">>, FormData),
            File2 =
                case save_file(FormData, [], ChatId) of
                    [] ->
                        [];
                    [File] ->
                        File
                end,

            Attachments = build_attachment(File2, ChatId),
            Message = attachments_message(Id, ChatId, Sender, Attachments, UserAgent),
            case chatli_db:create_message(Message) of
                ok ->
                    try thoas:encode(Message) of
                        Json ->
                            ok = chatli_ws_srv:publish(ChatId, Json),
                            {json, 201, #{}, #{id => Id}}
                    catch
                        _:_ -> {status, 500}
                    end;
                _ ->
                    {status, 500}
            end
    end;
message(#{
    headers := #{<<"user-agent">> := UserAgent},
    auth_data := #{id := UserId},
    json := Json
}) ->
    Id = chatli_uuid:get_v4(),
    #{<<"chat_id">> := ChatId} = Json,
    {ok, #{phone_number := PhoneNumber, email := Email}} = chatli_user_db:get(UserId),
    Object = maps:merge(
        #{
            <<"id">> => Id,
            <<"sender">> => UserId,
            <<"sender_info">> => #{
                <<"phone_number">> => PhoneNumber,
                <<"email">> => Email,
                <<"user_agent">> => UserAgent
            },
            <<"timestamp">> => os:system_time(millisecond),
            <<"type">> => <<"message">>,
            <<"action">> => <<"message">>
        },
        Json
    ),
    case chatli_db:create_message(Object) of
        ok ->
            ok = chatli_ws_srv:publish(ChatId, thoas:encode(Object)),
            {json, 201, #{}, #{id => Id}};
        _ ->
            {status, 400}
    end.
get_attachment(#{
    bindings := #{
        <<"attachmentid">> := AttachmentId,
        <<"chatid">> := ChatId
    }
}) ->
    case chatli_db:get_attachment(AttachmentId, ChatId) of
        undefined ->
            {status, 404};
        {ok, #{
            id := Id,
            chat_id := ChatId,
            mime := Mime,
            length := Length
        }} ->
            {ok, Path} = application:get_env(chatli, download_path),
            {sendfile, 200, #{}, {0, Length, Path ++ binary_to_list(Id)}, Mime}
    end.

get_attachment_no_auth(#{
    bindings := #{
        <<"attachmentid">> := AttachmentId,
        <<"chatid">> := ChatId
    }
}) ->
    case chatli_db:get_attachment(AttachmentId, ChatId) of
        undefined ->
            {status, 404};
        {ok, #{
            id := Id,
            chat_id := ChatId,
            mime := Mime,
            length := Length
        }} ->
            {ok, Path} = application:get_env(chatli, download_path),
            {sendfile, 200, #{}, {0, Length, Path ++ binary_to_list(Id)}, Mime}
    end.

get_history(#{
    json := #{
        <<"type">> := Type,
        <<"value">> := Value,
        <<"timestamp">> := Timestamp
    }
}) ->
    case chatli_user_db:find(Type, Value) of
        undefined ->
            {status, 200};
        {ok, #{id := UserId}} ->
            {ok, Result} = chatli_db:get_all_chats(UserId),
            MessageList = get_chat_messages(Result, Timestamp, []),
            send_callback(MessageList, UserId),
            {status, 200}
    end.

get_chat_messages([], _, Acc) ->
    Acc;
get_chat_messages([#{id := ChatId} | T], Timestamp, Acc) ->
    case chatli_db:get_filtered_messages(ChatId, #{<<"after">> => integer_to_binary(Timestamp)}) of
        {ok, Messages} ->
            get_chat_messages(T, Timestamp, Messages ++ Acc);
        _ ->
            get_chat_messages(T, Timestamp, Acc)
    end.

send_callback([], _) ->
    ok;
send_callback([Message | T], UserId) ->
    case encode(Message) of
        error ->
            send_callback(T, UserId);
        Json ->
            ok = chatli_ws_srv:callback(UserId, Json),
            send_callback(T, UserId)
    end.

encode(Message) ->
    try thoas:encode(Message) of
        Json -> Json
    catch
        _:_ -> error
    end.

get_archive(#{
    bindings := #{<<"chatid">> := ChatId},
    parsed_qs := QS
}) when map_size(QS) =:= 0 ->
    {ok, Result} = chatli_db:get_chat_messages(ChatId),
    {json, 200, #{}, Result};
get_archive(#{
    bindings := #{<<"chatid">> := ChatId},
    parsed_qs := QS
}) ->
    {ok, Result} = chatli_db:get_filtered_messages(ChatId, QS),
    {json, 200, #{}, Result}.

manage_message(#{
    bindings := #{
        <<"chatid">> := ChatId,
        <<"messageid">> := MessageId
    }
}) ->
    {ok, Message} = chatli_db:get_message(ChatId, MessageId),
    {json, 200, #{}, Message}.

get_chats(#{auth_data := #{id := UserId}}) ->
    case chatli_db:get_all_chats(UserId) of
        {ok, Chats} ->
            Chats2 = get_participants(Chats, UserId, []),
            {json, 200, #{}, Chats2};
        Error ->
            logger:warning("chat error: ~p", [Error]),
            {json, 200, #{}, []}
    end.

create_chat(#{
    json := #{
        <<"participants">> := Participants,
        <<"type">> := Type
    } = Json,
    auth_data := #{id := UserId}
}) ->
    Id = chatli_uuid:get_v4(),
    Object = maps:merge(#{<<"id">> => Id}, Json),
    case Type of
        <<"1to1">> ->
            [#{<<"id">> := UserId2}] = Participants,
            case chatli_db:get_dm_chat(UserId, UserId2) of
                undefined ->
                    create_chat(Object, UserId, Participants, Id);
                {ok, Chat} ->
                    [Chat0] = get_participants([Chat], UserId, []),
                    {json, 201, #{}, Chat0}
            end;
        _ ->
            create_chat(Object, UserId, Participants, Id)
    end.

get_chat(#{
    bindings := #{<<"chatid">> := ChatId},
    auth_data := #{id := UserId}
}) ->
    case chatli_db:get_chat(ChatId) of
        {ok, Chat} ->
            [Chat2 | _] = get_participants([Chat], UserId, []),
            {json, 201, #{}, Chat2};
        Error ->
            logger:warning("chat error: ~p", [Error]),
            {status, 500}
    end.

delete_chat(#{bindings := #{<<"chatid">> := ChatId}}) ->
    chatli_db:delete_chat(ChatId),
    {status, 200}.

participants(#{
    method := <<"GET">>,
    bindings := #{<<"chatid">> := ChatId},
    auth_data := #{id := UserId}
}) ->
    case chatli_db:get_all_other_participants(ChatId, UserId) of
        {ok, Participants} ->
            {json, 200, #{}, #{
                id => ChatId,
                participants => Participants
            }};
        Error ->
            logger:warning("participants error: ~p", [Error]),
            {status, 500}
    end;
participants(#{
    method := <<"POST">>,
    bindings := #{<<"chatid">> := ChatId},
    json := Json,
    auth_data := #{id := Sender}
}) ->
    #{<<"id">> := UserId} = Json,
    case chatli_db:add_participant(ChatId, UserId) of
        ok ->
            {ok, User} = chatli_user_db:get(UserId),
            Id = chatli_uuid:get_v4(),
            Message = event_message(Id, ChatId, Sender, User, <<"join">>),
            chatli_ws_srv:publish(ChatId, Message),
            {status, 201};
        Error ->
            logger:warning("participants error: ~p", [Error]),
            {status, 500}
    end.

manage_participants(#{
    method := <<"DELETE">>,
    bindings := #{
        <<"chatid">> := ChatId,
        <<"participantid">> := ParticipantId
    },
    auth_data := #{id := Sender}
}) ->
    chatli_db:remove_participant(ChatId, ParticipantId),
    {ok, User} = chatli_user_db:get(ParticipantId),
    Id = chatli_uuid:get_v4(),
    Message = event_message(Id, ChatId, Sender, User, <<"leave">>),
    try thoas:encode(Message) of
        Json ->
            ok = chatli_ws_srv:publish(ChatId, Json),
            {status, 200}
    catch
        _:_ -> {status, 500}
    end.

get_participants([], _, Acc) ->
    Acc;
get_participants([#{id := ChatId} = Chat | Chats], UserId, Acc) ->
    {ok, Participants} = chatli_db:get_all_other_participants(ChatId, UserId),
    get_participants(Chats, UserId, [maps:merge(#{participants => Participants}, Chat) | Acc]).

create_chat(Object, UserId, Participants, Id) ->
    case chatli_db:create_chat(Object) of
        ok ->
            [
                chatli_db:add_participant(Id, UserId2)
             || #{<<"id">> := UserId2} <- [#{<<"id">> => UserId} | Participants]
            ],
            {json, 201, #{}, Object};
        Error ->
            logger:warning("chat error: ~p", [Error]),
            {status, 500}
    end.

build_attachment([], _) ->
    #{};
build_attachment({ok, AttachmentId, Mime, _WhatIs}, ChatId) ->
    #{
        <<"url">> => <<"chat/", ChatId/binary, "/attachment/", AttachmentId/binary>>,
        <<"mime">> => Mime
    }.

-spec event_message(binary(), binary(), binary(), map(), binary()) -> map().
event_message(Id, ChatId, Sender, User, Action) ->
    #{
        <<"id">> => Id,
        <<"chat_id">> => ChatId,
        <<"sender">> => Sender,
        <<"payload">> => #{<<"user">> => User},
        <<"type">> => <<"event">>,
        <<"action">> => Action,
        <<"timestamp">> => os:system_time(millisecond)
    }.

-spec attachments_message(binary(), binary(), binary(), map(), binary()) -> map().
attachments_message(Id, ChatId, Sender, Attachments, UserAgent) ->
    {ok, #{phone_number := PhoneNumber, email := Email}} = chatli_user_db:get(Sender),
    #{
        <<"id">> => Id,
        <<"chat_id">> => ChatId,
        <<"sender">> => Sender,
        <<"sender_info">> => #{
            <<"phone_number">> => PhoneNumber,
            <<"email">> => Email,
            <<"user_agent">> => UserAgent
        },
        <<"payload">> => Attachments,
        <<"type">> => <<"message">>,
        <<"action">> => <<"attachments">>,
        <<"timestamp">> => os:system_time(millisecond)
    }.

save_file([], Acc, _) ->
    Acc;
save_file([{file, Bytes, Mime, ByteSize} | T], Acc, ChatId) ->
    UUID = chatli_uuid:get_v4(),
    {ok, Path} = application:get_env(chatli, download_path),
    File = Path ++ binary_to_list(UUID),
    ok = filelib:ensure_dir(File),
    case file:write_file(File, Bytes) of
        ok ->
            case chatli_db:create_attachment(UUID, ChatId, Mime, ByteSize) of
                ok ->
                    save_file(T, [{ok, UUID, Mime, ByteSize} | Acc], ChatId);
                _ ->
                    save_file([{error, create_attachment} | T], Acc, ChatId)
            end;
        Error ->
            save_file(T, [Error | Acc], ChatId)
    end;
save_file([_ | T], Acc, ChatId) ->
    save_file(T, Acc, ChatId).
