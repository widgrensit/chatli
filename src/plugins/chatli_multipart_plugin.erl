-module(chatli_multipart_plugin).

-export([
    pre_request/4,
    post_request/4,
    plugin_info/0
]).

%%--------------------------------------------------------------------
%% @doc
%% Pre-request callback
%% @end
%%--------------------------------------------------------------------
-spec pre_request(Req :: cowboy_req:req(), Env :: any(), Options :: map(), State :: any()) ->
    {ok, Req0 :: cowboy_req:req(), NewState :: any()}.
pre_request(
    #{headers := #{<<"content-type">> := <<"multipart/form-data", _/binary>>}} = Req,
    _Env,
    _Options,
    State
) ->
    {Req1, FormData} = multipart(Req, []),
    {ok, Req1#{multipart_data => FormData}, State};
pre_request(Req, _Env, _Options, State) ->
    {ok, Req, State}.

%%--------------------------------------------------------------------
%% @doc
%% Post-request callback
%% @end
%%--------------------------------------------------------------------
-spec post_request(Req :: cowboy_req:req(), Env :: any(), Options :: map(), State :: any()) ->
    {ok, Req0 :: cowboy_req:req(), NewState :: any()}.
post_request(Req, _Env, _Options, State) ->
    {ok, Req, State}.

%%--------------------------------------------------------------------
%% @doc
%% nova_plugin callback. Returns information about the plugin.
%% @end
%%--------------------------------------------------------------------
-spec plugin_info() ->
    {Title :: binary(), Version :: binary(), Author :: binary(), Description :: binary(), [
        {Key :: atom(), OptionDescription :: atom()}
    ]}.
plugin_info() ->
    {<<"Plugin name plugin">>, <<"0.0.1">>, <<"User <user@email.com">>, <<"Descriptive text">>,
        %% Options is specified as {Key, Description}
        []}.

multipart(Req0, Acc) ->
    case cowboy_req:read_part(Req0) of
        {ok, Headers, Req1} ->
            case cow_multipart:form_data(Headers) of
                {data, FieldName} ->
                    {ok, Body, Req2} = cowboy_req:read_part_body(Req1),
                    multipart(Req2, [{FieldName, Body} | Acc]);
                {file, _FieldName, Filename, _CType} ->
                    {Req2, TmpFile, ByteSize} = stream_file(Req1, <<>>),
                    Mime = mimerl:filename(Filename),
                    multipart(Req2, [{file, TmpFile, Mime, ByteSize} | Acc])
            end;
        {done, Req1} ->
            {Req1, Acc}
    end.

stream_file(Req0, Body) ->
    case cowboy_req:read_part_body(Req0) of
        {ok, LastBodyChunk, Req} ->
            Chunk = <<Body/binary, LastBodyChunk/binary>>,
            {Req, Chunk, byte_size(Chunk)};
        {more, BodyChunk, Req} ->
            stream_file(Req, <<Body/binary, BodyChunk/binary>>)
    end.
