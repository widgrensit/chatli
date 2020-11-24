CREATE TABLE chatli_user
(
    id uuid PRIMARY KEY,
    username varchar NOT NULL UNIQUE,
    phone_number varchar UNIQUE,
    email varchar UNIQUE,
    avatar varchar,
    password varchar NOT NULL
);

CREATE TABLE message
(
    id uuid PRIMARY KEY,
    chat_id uuid NOT NULL,
    payload varchar,
    sender uuid NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE chat
(
    id uuid PRIMARY KEY,
    name varchar NOT NULL,
    description varchar
);

CREATE TABLE participant
(
    id SERIAL PRIMARY KEY,
    chat_id uuid,
    user_id uuid
);

CREATE TABLE device
(
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR
);

CREATE TYPE push_type AS ENUM
('fcm', 'apns.alert', 'apns.voip');

CREATE TABLE push_token
(
    id uuid NOT NULL REFERENCES device(id) ON DELETE CASCADE,
    type push_type NOT NULL,
    token varchar,
    modified timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(device_id, type)
);

CREATE TABLE callback
(
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    url VARCHAR NOT NULL
);