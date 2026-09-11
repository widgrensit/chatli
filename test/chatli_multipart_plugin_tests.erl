-module(chatli_multipart_plugin_tests).

-include_lib("eunit/include/eunit.hrl").

passthrough_keeps_request_and_state_test() ->
    Req = #{headers => #{~"content-type" => ~"application/json"}},
    ?assertEqual({ok, Req, state}, chatli_multipart_plugin:pre_request(Req, #{}, #{}, state)).

passthrough_sets_no_multipart_data_test() ->
    {ok, Req, _} = chatli_multipart_plugin:pre_request(#{headers => #{}}, #{}, #{}, undefined),
    ?assertNot(maps:is_key(multipart_data, Req)).

post_request_is_identity_test() ->
    Req = #{headers => #{}},
    ?assertEqual({ok, Req, state}, chatli_multipart_plugin:post_request(Req, #{}, #{}, state)).
