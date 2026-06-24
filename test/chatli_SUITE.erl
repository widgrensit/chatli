-module(chatli_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

-define(BASEPATH, <<"http://localhost:8090">>).
-define(IP, "localhost").
-define(PORT, 8090).

%%--------------------------------------------------------------------
%% @spec suite() -> Info
%% Info = [tuple()]
%% @end
%%--------------------------------------------------------------------
suite() ->
    [{timetrap, {seconds, 30}}].

%%--------------------------------------------------------------------
%% @spec init_per_suite(Config0) ->
%%     Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_suite(_Config) ->
    application:ensure_all_started(ssl),
    application:ensure_all_started(gun),
    Username = <<"username1">>,
    Password = <<"1234">>,
    Username2 = <<"username2">>,
    Password2 = <<"12345">>,
    User1 = #{
        <<"email">> => <<"my@email.com">>,
        <<"username">> => Username,
        <<"password">> => Password
    },
    User2 = #{
        <<"phoneNumber">> => <<"123456">>,
        <<"username">> => Username2,
        <<"password">> => Password2
    },
    Path = [?BASEPATH, <<"/v1/signup">>],
    #{status := {201, _}} = jhn_shttpc:post(Path, encode(User1), opts()),
    Path = [?BASEPATH, <<"/v1/signup">>],
    #{status := {201, _}} = jhn_shttpc:post(Path, encode(User2), opts()),
    LoginPath = [?BASEPATH, <<"/v1/login">>],
    #{status := {200, _}, body := LoginRespBody} = jhn_shttpc:post(
        LoginPath,
        encode(#{
            username => Username,
            password => Password
        }),
        opts()
    ),
    #{<<"access_token">> := Token} = decode(LoginRespBody),
    [_, Payload, _] = jhn_bstring:tokens(Token, <<".">>),
    UserObj1 = decode(base64:decode(Payload, #{mode => urlsafe, padding => false})),
    #{status := {200, _}, body := LoginRespBody2} = jhn_shttpc:post(
        LoginPath,
        encode(#{
            username => Username2,
            password => Password2
        }),
        opts()
    ),
    #{<<"access_token">> := Token2} = decode(LoginRespBody2),
    [_, Payload2, _] = jhn_bstring:tokens(Token2, <<".">>),
    #{<<"id">> := UserId2} =
        UserObj2 = decode(base64:decode(Payload2, #{mode => urlsafe, padding => false})),
    CallbackPath = [?BASEPATH, <<"/v1/callback">>],
    CallbackObject = #{
        type => <<"email">>,
        value => <<"my@email.com">>,
        url => <<"http://localhost:8095/receiver">>
    },
    #{status := {200, _}, body := CallbackRespBody} = jhn_shttpc:post(
        CallbackPath, encode(CallbackObject), opts()
    ),
    Chat = #{
        <<"name">> => <<"my c hat">>,
        <<"description">> => <<"This is a c hat">>,
        <<"type">> => <<"1to1">>,
        <<"participants">> => [#{<<"id">> => UserId2}]
    },
    ChatPath = [?BASEPATH, <<"/client/chat">>],
    #{status := {201, _}, body := ChatRespBody} = jhn_shttpc:post(
        ChatPath, encode(Chat), opts(Token)
    ),
    Device = #{<<"name">> => <<"my device">>},
    DeviceId = list_to_binary(uuid:uuid_to_string(uuid:get_v4())),
    DevicePath = [?BASEPATH, <<"/client/device/">>, DeviceId],
    #{status := {200, _}} = jhn_shttpc:put(DevicePath, encode(Device), opts(Token)),
    [
        {user1, #{
            object => UserObj1,
            token => Token
        }},
        {user2, #{
            object => UserObj2,
            token => Token2
        }},
        {chat, decode(ChatRespBody)},
        {device, maps:merge(#{<<"id">> => DeviceId}, Device)},
        {callback, decode(CallbackRespBody)},
        {timestamp, os:system_time(millisecond)}
    ].

%%--------------------------------------------------------------------
%% @spec end_per_suite(Config0) -> term() | {save_config,Config1}
%% Config0 = Config1 = [tuple()]
%% @end
%%--------------------------------------------------------------------
end_per_suite(Config) ->
    #{
        object := #{<<"id">> := Id},
        token := Token
    } = proplists:get_value(user1, Config),
    #{
        object := #{<<"id">> := Id2},
        token := Token2
    } = proplists:get_value(user2, Config),
    Path = [?BASEPATH, <<"/client/user/">>, Id],
    jhn_shttpc:delete(Path, opts(Token)),
    Path2 = [?BASEPATH, <<"/client/user/">>, Id2],
    jhn_shttpc:delete(Path2, opts(Token2)),
    #{<<"id">> := ChatId} = proplists:get_value(chat, Config),
    ChatPath = [?BASEPATH, <<"/client/chat/">>, ChatId],
    #{status := {200, _}} = jhn_shttpc:delete(ChatPath, opts(Token)),
    #{<<"id">> := DeviceId} = proplists:get_value(device, Config),
    DevicePath = [?BASEPATH, <<"/client/device/">>, DeviceId],
    #{status := {200, _}} = jhn_shttpc:delete(DevicePath, opts(Token)),
    #{<<"id">> := CallbackId} = proplists:get_value(callback, Config),
    CallbackPath = [?BASEPATH, <<"/v1/callback/">>, CallbackId],
    #{status := {200, _}} = jhn_shttpc:delete(CallbackPath, opts()),
    ok.

%%--------------------------------------------------------------------
%% @spec init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_group(_GroupName, Config) ->
    Config.

%%--------------------------------------------------------------------
%% @spec end_per_group(GroupName, Config0) ->
%%               term() | {save_config,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% @end
%%--------------------------------------------------------------------
end_per_group(_GroupName, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% @spec init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% TestCase = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_testcase(_TestCase, Config) ->
    Config.

%%--------------------------------------------------------------------
%% @spec end_per_testcase(TestCase, Config0) ->
%%               term() | {save_config,Config1} | {fail,Reason}
%% TestCase = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
end_per_testcase(_TestCase, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% @spec groups() -> [Group]
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%% Shuffle = shuffle | {shuffle,{integer(),integer(),integer()}}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%% N = integer() | forever
%% @end
%%--------------------------------------------------------------------
groups() ->
    [].

%%--------------------------------------------------------------------
%% @spec all() -> GroupsAndTestCases | {skip,Reason}
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%% TestCase = atom()
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
all() ->
    [
        get_all_users,
        list_participant,
        get_all_chats,
        create_same_chat_again,
        send_message,
        get_all_message,
        get_filtered_message,
        get_historic_message,
        upload_attachment,
        remove_participant,
        get_all_devices,
        get_callback
    ].

%%--------------------------------------------------------------------
%% @spec TestCase(Config0) ->
%%               ok | exit() | {skip,Reason} | {comment,Comment} |
%%               {save_config,Config1} | {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% Comment = term()
%% @end
%%--------------------------------------------------------------------
get_all_users(Config) ->
    #{token := Token} = proplists:get_value(user1, Config),
    Path = [?BASEPATH, <<"/client/user">>],
    #{status := {200, _}, body := RespBody} = jhn_shttpc:get(Path, opts(Token)),
    4 = length(decode(RespBody)).

add_participant(Config) ->
    #{token := Token} = proplists:get_value(user1, Config),
    #{object := #{id := UserId2}} = proplists:get_value(user2, Config),
    #{id := ChatId} = proplists:get_value(chat, Config),
    Path = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/participant">>],
    #{status := {201, _}} = jhn_shttpc:post(Path, encode(#{id => UserId2}), opts(Token)).

list_participant(Config) ->
    #{token := Token} = proplists:get_value(user1, Config),
    #{<<"id">> := ChatId} = proplists:get_value(chat, Config),
    Path = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/participant">>],
    #{status := {200, _}, body := RespBody} = jhn_shttpc:get(Path, opts(Token)),
    #{<<"participants">> := Participants} = decode(RespBody),
    1 = length(Participants).

get_all_chats(Config) ->
    #{token := Token} = proplists:get_value(user1, Config),
    Path = [?BASEPATH, <<"/client/chat/">>],
    #{status := {200, _}, body := RespBody} = jhn_shttpc:get(Path, opts(Token)),
    [#{<<"participants">> := Participants}] = decode(RespBody),
    1 = length(Participants).

create_same_chat_again(Config) ->
    #{<<"id">> := ChatId} = proplists:get_value(chat, Config),
    #{token := Token} = proplists:get_value(user1, Config),
    #{object := #{<<"id">> := UserId2}} = proplists:get_value(user2, Config),
    Chat = #{
        <<"name">> => <<"my c hat">>,
        <<"description">> => <<"This is a c hat">>,
        <<"type">> => <<"1to1">>,
        <<"participants">> => [#{<<"id">> => UserId2}]
    },
    ChatPath = [?BASEPATH, <<"/client/chat">>],
    #{status := {201, _}, body := ChatRespBody} = jhn_shttpc:post(
        ChatPath, encode(Chat), opts(Token)
    ),
    #{<<"id">> := ChatId} = decode(ChatRespBody).

remove_participant(Config) ->
    #{token := Token} = proplists:get_value(user1, Config),
    #{object := #{<<"id">> := UserId2}} = proplists:get_value(user2, Config),
    #{<<"id">> := ChatId} = proplists:get_value(chat, Config),
    Path = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/participant/">>, UserId2],
    #{status := {200, _}} = jhn_shttpc:delete(Path, opts(Token)),
    ListPath = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/participant">>],
    #{status := {200, _}, body := RespBody} = jhn_shttpc:get(ListPath, opts(Token)),
    #{<<"participants">> := Participants} = decode(RespBody),
    0 = length(Participants).

send_message(Config) ->
    #{
        token := Token,
        object := #{<<"id">> := UserId}
    } = proplists:get_value(user1, Config),
    #{<<"id">> := ChatId} = proplists:get_value(chat, Config),
    #{<<"id">> := DeviceId} = proplists:get_value(device, Config),
    websocket([<<"/client/device/">>, DeviceId, <<"/user/">>, UserId, <<"/ws">>], Token),
    Path = [?BASEPATH, <<"/client/message">>],
    #{status := {201, _}, body := MessageBody} = jhn_shttpc:post(
        Path,
        encode(#{
            chat_id => ChatId,
            payload => <<"hi hi">>
        }),
        opts(Token)
    ),
    #{<<"id">> := MessageId} = decode(MessageBody),
    await_ws_message(MessageId).

get_all_message(Config) ->
    #{token := Token} = proplists:get_value(user1, Config),
    #{<<"id">> := ChatId} = proplists:get_value(chat, Config),
    Path = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/message">>],
    #{status := {200, _}, body := RespBody} = jhn_shttpc:get(Path, opts(Token)),
    [#{<<"id">> := MessageId}] = [MessageObj] = decode(RespBody),
    MessagePath = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/message/">>, MessageId],
    #{status := {200, _}, body := MessageRespBody} = jhn_shttpc:get(MessagePath, opts(Token)),
    #{<<"id">> := MessageId} = MessageObj = decode(MessageRespBody).

get_filtered_message(Config) ->
    #{token := Token} = proplists:get_value(user1, Config),
    #{<<"id">> := ChatId} = proplists:get_value(chat, Config),
    StartTimestamp = integer_to_binary(proplists:get_value(timestamp, Config)),
    Path = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/message?after=">>, StartTimestamp],
    #{status := {200, _}, body := RespBody} = jhn_shttpc:get(Path, opts(Token)),
    [#{<<"id">> := MessageId}] = [MessageObj] = decode(RespBody),
    MessagePath = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/message/">>, MessageId],
    #{status := {200, _}, body := MessageRespBody} = jhn_shttpc:get(MessagePath, opts(Token)),
    #{<<"id">> := MessageId} = MessageObj = decode(MessageRespBody),
    Path2 = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/message?before=">>, StartTimestamp],
    #{status := {200, _}, body := RespBody2} = jhn_shttpc:get(Path2, opts(Token)),
    [] = decode(RespBody2).

get_historic_message(Config) ->
    Path = [?BASEPATH, <<"/v1/history">>],
    Body = encode(#{
        type => <<"email">>,
        value => <<"my@email.com">>,
        timestamp => proplists:get_value(timestamp, Config)
    }),
    #{status := {200, _}} = jhn_shttpc:post(Path, Body, opts()).

get_all_devices(Config) ->
    #{token := Token} = proplists:get_value(user1, Config),
    #{<<"id">> := DeviceId} = DeviceObj = proplists:get_value(device, Config),
    Path = [?BASEPATH, <<"/client/device">>],
    #{status := {200, _}, body := RespBody} = jhn_shttpc:get(Path, opts(Token)),
    [#{<<"id">> := DeviceId2}] = [DeviceObj] = decode(RespBody),
    DeviceId = DeviceId2,
    DevicePath = [?BASEPATH, <<"/client/device/">>, DeviceId],
    #{status := {200, _}, body := DeviceRespBody} = jhn_shttpc:get(DevicePath, opts(Token)),
    #{<<"id">> := DeviceId} = DeviceObj = decode(DeviceRespBody).

get_callback(Config) ->
    #{<<"id">> := CallbackId} = proplists:get_value(callback, Config),
    Path = [?BASEPATH, <<"/v1/callback/">>, CallbackId],
    #{status := {200, _}, body := RespBody} = jhn_shttpc:get(Path, opts()),
    #{<<"id">> := CallbackId} = decode(RespBody).

upload_attachment(Config) ->
    #{
        token := Token,
        object := #{<<"id">> := UserId}
    } = proplists:get_value(user1, Config),
    #{<<"id">> := ChatId} = proplists:get_value(chat, Config),
    #{<<"id">> := DeviceId} = proplists:get_value(device, Config),
    websocket([<<"/client/device/">>, DeviceId, <<"/user/">>, UserId, <<"/ws">>], Token),
    Path = [?BASEPATH, <<"/client/message">>],
    {ok, Cwd} = file:get_cwd(),
    Tokenized = string:tokens(Cwd, "/"),
    {NewPath, _} = lists:splitwith(fun(X) -> X =/= "chatli" end, Tokenized),
    NewPath2 = "/" ++ string:join(NewPath, "/") ++ "/chatli/test/",
    {ok, Data} = file:read_file(NewPath2 ++ "itworks.jpg"),
    Filename = filename:basename(NewPath2 ++ "itworks.jpg"),
    Boundary = chatli_uuid:get_v4(),
    Formatted = format_multipart_formdata(
        Data, [{<<"chat_id">>, ChatId}], <<"itworks">>, [Filename], <<"image/jpeg">>, Boundary
    ),
    #{status := {201, _}, body := MessageBody} = jhn_shttpc:post(
        Path, Formatted, opts(attachment, Token, Boundary)
    ),
    #{<<"id">> := MessageId} = decode(MessageBody),
    await_ws_message(MessageId),
    MessagePath = [?BASEPATH, <<"/client/chat/">>, ChatId, <<"/message/">>, MessageId],
    #{status := {200, _}, body := MessageRespBody} = jhn_shttpc:get(MessagePath, opts(Token)),
    #{
        <<"id">> := MessageId,
        <<"payload">> := #{<<"url">> := Url}
    } = decode(MessageRespBody),
    ct:log("attachment url: ~p", [Url]),
    AttachmentPath = [?BASEPATH, "/client/", Url],
    #{status := {200, _}, body := AttachmentBody} = jhn_shttpc:get(AttachmentPath, opts(Token)),
    AttachmentBody = Data.

opts() ->
    opts(undefined).
opts(undefined) ->
    #{
        headers => #{
            'Content-Type' => <<"application/json">>,
            'Accept' => <<"application/json">>
        },
        close => true
    };
opts(Token) ->
    ct:log("Token is: ~p", [Token]),
    Res = #{
        headers => #{
            'Content-Type' => <<"application/json">>,
            'Accept' => <<"application/json">>,
            'Authorization' => <<"Bearer ", Token/binary>>,
            'User-Agent' => <<"Test client">>
        },
        close => true
    },
    ct:log("Returning opts: ~p", [Res]),
    Res.

opts(attachment, Token, Boundary) ->
    ct:log("Token is: ~p", [Token]),
    Res = #{
        headers => #{
            'Content-Type' => <<"multipart/form-data; boundary=", Boundary/binary>>,
            'Authorization' => <<"Bearer ", Token/binary>>,
            'User-Agent' => <<"Test client">>
        },
        close => true
    },
    ct:log("Returning opts: ~p", [Res]),
    Res.

decode(Json) ->
    {ok, Decode} = thoas:decode(Json),
    Decode.

%% The server redelivers undelivered messages on reconnect, so skip
%% anything that isn't the message we are waiting for.
await_ws_message(MessageId) ->
    receive
        {gun_ws, _ConnPid, _StreamRef, {text, Msg}} ->
            case decode(Msg) of
                #{<<"id">> := MessageId} -> ok;
                _ -> await_ws_message(MessageId)
            end
    after 8000 ->
        exit(timeout)
    end.

encode(Json) ->
    thoas:encode(Json).

websocket(Path, Token) ->
    {ok, ConnPid} = gun:open(?IP, ?PORT, #{transport => tcp}),
    {ok, _Protocol} = gun:await_up(ConnPid),
    io:format("ConnPid: ~p", [ConnPid]),
    gun:ws_upgrade(ConnPid, Path, [{<<"authorization">>, <<"bearer ", Token/binary>>}]),

    receive
        {gun_upgrade, ConnPid, _StreamRef, _Protocols, _Headers} ->
            ConnPid;
        {gun_response, ConnPid, _, _, Status, Headers} ->
            exit({ws_upgrade_failed, Status, Headers});
        {gun_error, _ConnPid, _StreamRef, Reason} ->
            exit({ws_upgrade_failed, Reason});
        Err ->
            io:format("WS unexpectedly received ~p", [Err])

        %% More clauses here as needed.
    after 2000 ->
        exit(timeout)
    end.

-spec format_multipart_formdata(Data, Params, Name, FileNames, MimeType, Boundary) -> binary() when
    Data :: binary(),
    Params :: list(),
    Name :: binary(),
    FileNames :: list(),
    MimeType :: binary(),
    Boundary :: binary().
format_multipart_formdata(Data, Params, Name, FileNames, MimeType, Boundary) ->
    StartBoundary = erlang:iolist_to_binary([<<"--">>, Boundary]),
    LineSeparator = <<"\r\n">>,
    WithParams = lists:foldl(
        fun({Key, Value}, Acc) ->
            erlang:iolist_to_binary([
                Acc,
                StartBoundary,
                LineSeparator,
                <<"Content-Disposition: form-data; name=\"">>,
                Key,
                <<"\"">>,
                LineSeparator,
                LineSeparator,
                Value,
                LineSeparator
            ])
        end,
        <<"">>,
        Params
    ),
    WithPaths = lists:foldl(
        fun(FileName, Acc) ->
            erlang:iolist_to_binary([
                Acc,
                StartBoundary,
                LineSeparator,
                <<"Content-Disposition: form-data; name=\"">>,
                Name,
                <<"\"; filename=\"">>,
                FileName,
                <<"\"">>,
                LineSeparator,
                <<"Content-Type: ">>,
                MimeType,
                LineSeparator,
                LineSeparator,
                Data,
                LineSeparator
            ])
        end,
        WithParams,
        FileNames
    ),
    erlang:iolist_to_binary([WithPaths, StartBoundary, <<"--">>, LineSeparator]).
