CREATE DATABASE ldf;

\c ldf;

CREATE TABLE li
(
    id SERIAL PRIMARY KEY,
    type VARCHAR NOT NULL,
    value VARCHAR NOT NULL,
    callback_id uuid NOT NULL,
    user_id uuid NOT NULL,
    username VARCHAR,
    phone_number VARCHAR,
    email VARCHAR
);

CREATE TABLE ldf_message
(
    id SERIAL PRIMARY KEY,
    message_id UUID NOT NULL,
    payload VARCHAR,
    content_length VARCHAR
);