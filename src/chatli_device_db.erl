-module(chatli_device_db).

-export([
    upsert/3,
    delete/2,
    get/2,
    get_all/1
]).

upsert(DeviceId, UserId, Name) ->
    delete(DeviceId, UserId),
    SQL =
        <<
            "INSERT INTO\n"
            "               device\n"
            "               (\n"
            "                 id,\n"
            "                 user_id,\n"
            "                 name\n"
            "               ) VALUES (\n"
            "                 $1,\n"
            "                 $2,\n"
            "                 $3\n"
            "               )"
        >>,
    chatli_db:query1(SQL, [DeviceId, UserId, Name]).

delete(DeviceId, UserId) ->
    SQL =
        <<
            "DELETE FROM\n"
            "                device\n"
            "            WHERE\n"
            "                id = $1 AND\n"
            "                user_id = $2"
        >>,
    chatli_db:query(SQL, [DeviceId, UserId]).

get(DeviceId, UserId) ->
    SQL = <<"SELECT id, name FROM device WHERE id = $1 AND user_id = $2">>,
    chatli_db:query1(SQL, [DeviceId, UserId]).

get_all(UserId) ->
    SQL = <<"SELECT id, name FROM device WHERE user_id = $1">>,
    chatli_db:query(SQL, [UserId]).
