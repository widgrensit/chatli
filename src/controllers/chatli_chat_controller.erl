-module(chatli_chat_controller).
-export([
         message/1,
         get_archive/1,
         manage_message/1,
         chat/1,
         manage_chat/1,
         participants/1,
         manage_participants/1
        ]).

message(#{req := #{method := <<"POST">>},
          auth_data := #{id := UserId},
          json := Json}) ->
    Id = chatli_uuid:get_v4(),
    #{<<"chatId">> := ChatId} = Json,
    Object = maps:merge(#{<<"id">> => Id,
                          <<"sender">> => UserId,
                          <<"timestamp">> => os:system_time(millisecond)}, Json),
    case chatli_db:create_message(Object) of
        ok ->
            ok = chatli_ws_srv:publish(ChatId, json:encode(Object, [maps, binary])),
            {json, 201, #{}, #{id => Id}};
        _ ->
            {status, 400}
    end;
message(#{req := #{method := <<"POST">>} = Req,
          auth_data := #{id := Sender}}) ->
    Id = chatli_uuid:get_v4(),
    case multipart(Req) of
        [] ->
            logger:debug("Empty form data"),
            {status, 200};
        FormData ->
            FileList = save_file(FormData, []),
            Attachments = build_attachment(FileList, []),
            ChatId = proplists:get_value(<<"chat_id">>, FormData),
            Message = attachments_message(Id, ChatId, Sender, Attachments),
            try json:encode(Message, [binary, maps]) of
                Json -> ok = chatli_ws_srv:publish(ChatId, Json),
                    {json, 201, #{}, #{id => Id}}
            catch _:_ -> {status, 500}
            end
    end.

get_archive(#{req := #{method := <<"GET">>,
                       bindings := #{chatid := ChatId}}}) ->
    {ok, Result} = chatli_db:get_chat_messages(ChatId),
    {json, 200, #{}, Result}.

manage_message(#{req := #{method := <<"GET">>,
                          bindings := #{chatid := ChatId,
                                        messageid := MessageId}}}) ->
    {ok, Message} = chatli_db:get_message(ChatId, MessageId),
    {json, 200, #{}, Message}.

chat(#{req := #{method := <<"GET">>},
       auth_data := #{id := UserId}}) ->
    case chatli_db:get_all_chats(UserId) of
        {ok, Chats} ->
            Chats2 = get_participants(Chats, UserId, []),
            {json, 200, #{}, Chats2};
        Error ->
            logger:warning("chat error: ~p", [Error]),
            {json, 200, #{}, []}
    end;
chat(#{req := #{method := <<"POST">>},
       json := #{<<"participants">> := Participants,
                 <<"type">> := Type} = Json,
       auth_data := #{id := UserId}}) ->
    Id = list_to_binary(uuid:uuid_to_string(uuid:get_v4())),
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

manage_chat(#{req := #{ method := <<"GET">>,
                        bindings := #{chatid := ChatId}}}) ->
    case chatli_db:get_chat(ChatId) of
        {ok, Chat} ->
            {json, 201, #{}, Chat};
        Error ->
            logger:warning("chat error: ~p", [Error]),
            {status, 500}
    end;
manage_chat(#{req := #{ method := <<"DELETE">>,
                        bindings := #{chatid := ChatId}}}) ->
    chatli_db:delete_chat(ChatId),
    {status, 200}.

participants(#{req := #{method := <<"GET">>,
                        bindings := #{chatid := ChatId}},
               auth_data := #{id := UserId}}) ->
    case chatli_db:get_all_other_participants(ChatId, UserId) of
        {ok, Participants} ->
            {json, 200, #{}, #{id => ChatId,
                               participants => Participants}};
        Error ->
            logger:warning("participants error: ~p", [Error]),
            {status, 500}
    end;
participants(#{ req := #{method := <<"POST">>,
                         bindings := #{chatid := ChatId}},
                json := Json,
                auth_data := #{id := Sender}}) ->
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

manage_participants(#{req := #{ method := <<"DELETE">>,
                                bindings := #{chatid := ChatId,
                                              participantid := ParticipantId}},
                      auth_data := #{id := Sender}}) ->
    chatli_db:remove_participant(ChatId, ParticipantId),
    {ok, User} = chatli_user_db:get(ParticipantId),
    Id = chatli_uuid:get_v4(),
    Message = event_message(Id, ChatId, Sender, User, <<"leave">>),
    try json:encode(Message, [binary, maps]) of
        Json -> ok = chatli_ws_srv:publish(ChatId, Json),
                {status, 200}
    catch _:_ -> {status, 500}
    end.

get_participants([], _, Acc) ->
    Acc;
get_participants([#{id := ChatId} = Chat | Chats], UserId, Acc) ->
    {ok, Participants} = chatli_db:get_all_other_participants(ChatId, UserId),
    get_participants(Chats, UserId, [maps:merge(#{participants => Participants}, Chat) | Acc]).


create_chat(Object, UserId, Participants, Id) ->
    case chatli_db:create_chat(Object) of
         ok ->
            [chatli_db:add_participant(Id, UserId2) || #{<<"id">> := UserId2} <- [#{<<"id">> => UserId} | Participants]],
            {json, 201, #{}, Object};
        Error ->
            logger:warning("chat error: ~p", [Error]),
            {status, 500}
    end.

build_attachment([], Acc) ->
    Acc;
build_attachment([{ok, AttachmentId, Mime}|T], Acc) ->
    Attachment = #{url => <<"v1/attachments/", AttachmentId/binary>>,
                   mime => Mime},
    build_attachment(T, [Attachment|Acc]).

-spec event_message(binary(), binary(), binary(), map(), binary()) -> map().
event_message(Id, ChatId, Sender, User, Action) ->
    #{<<"id">> => Id,
      <<"chatId">> => ChatId,
      <<"sender">> => Sender,
      <<"payload">> => #{<<"user">> => User},
      <<"type">> => <<"event">>,
      <<"action">> => Action,
      <<"timestamp">> => os:system_time(millisecond)}.

-spec attachments_message(binary(), binary(), binary(), list(map())) -> map().
attachments_message(Id, ChatId, Sender, Attachments) ->
    #{<<"id">> => Id,
      <<"chatId">> => ChatId,
      <<"sender">> => Sender,
      <<"payload">> => Attachments,
      <<"type">> => <<"message">>,
      <<"action">> => <<"attachments">>,
      <<"timestamp">> => os:system_time(millisecond)}.

save_file([], Acc) ->
    Acc;
save_file([{file, Bytes, Mime}|T], Acc) ->
    UUID = chatli_uuid:get_v4(),
    {ok, Path} = application:get_env(chatli, download_path),
    logger:debug("path: ~p", [Path]),
    case file:write(Path ++ binary_to_list(UUID), Bytes) of
        ok ->
            save_file(T, [{ok, UUID, Mime}|Acc]);
        Error ->
            save_file(T, [Error|Acc])
    end;
save_file([_|T], Acc) ->
    save_file(T, Acc).

multipart(Req0) ->
    case cowboy_req:read_part(Req0) of
        {ok, Headers, Req1} ->
            case cow_multipart:form_data(Headers) of
                {data, FieldName} ->
                    logger:debug("FieldName: ~p", [FieldName]),
                    {ok, Body, Req2} = cowboy_req:read_part_body(Req1),
                    [{FieldName, Body}| multipart(Req2)];
                {file, FieldName, Filename, CType} ->
                    logger:debug("FieldName: ~p FileName: ~p CType: ~p", [FieldName, Filename, CType]),
                    {Req2, TmpFile} = stream_file(Req1, <<>>),
                    Mime = <<"image/jpeg">>,
                    [{file, TmpFile, Mime}|multipart(Req2)]
            end;
        {done, _} ->
            []
    end.

stream_file(Req0, Body) ->
    case cowboy_req:read_part_body(Req0) of
        {ok, LastBodyChunk, Req} ->
            {Req, <<Body/binary, LastBodyChunk/binary>>};
        {more, BodyChunk, Req} ->
            stream_file(Req, <<Body/binary, BodyChunk/binary>>)
    end.