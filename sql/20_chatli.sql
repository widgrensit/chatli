CREATE DATABASE chatli;

\c  chatli;

CREATE EXTENSION pgcrypto;

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
    payload jsonb,
    sender uuid NOT NULL,
    type varchar,
    action varchar,
    timestamp bigint,
    sender_info jsonb
);

CREATE TABLE chat
(
    id uuid PRIMARY KEY,
    name varchar NOT NULL,
    description varchar,
    type varchar
);

CREATE TABLE participant
(
    id SERIAL PRIMARY KEY,
    chat_id uuid,
    user_id uuid,
    UNIQUE(chat_id, user_id)
);

CREATE TABLE callback
(
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    url VARCHAR NOT NULL
);


CREATE TABLE device
(
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR
);

CREATE TABLE attachment
(
    id UUID PRIMARY KEY,
    chat_id UUID NOT NULL,
    mime VARCHAR NOT NULL,
    length INTEGER
);

INSERT INTO chatli_user (id, username, phone_number, email, password) VALUES (gen_random_uuid(), 'alice', '461234', 'alice@example.com', 'alice');
INSERT INTO chatli_user (id, username, phone_number, email, password) VALUES (gen_random_uuid(), 'bob', '462345', 'bob@example.com', 'bob');
INSERT INTO chatli_user (id, username, phone_number, email, password) VALUES (gen_random_uuid(), 'ceasar', '463456', 'ceasar@example.com', 'ceasar');