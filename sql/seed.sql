-- Sample users for local dev and tests. Apply AFTER the app has booted
-- and run its kura migrations (tables are created on boot, not here):
--   docker exec chatli-db-1 psql -U postgres -d chatli -f /seed/seed.sql
INSERT INTO chatli_user (id, username, phone_number, email, password)
VALUES (gen_random_uuid(), 'alice', '461234', 'alice@example.com', 'alice')
ON CONFLICT DO NOTHING;
INSERT INTO chatli_user (id, username, phone_number, email, password)
VALUES (gen_random_uuid(), 'bob', '462345', 'bob@example.com', 'bob')
ON CONFLICT DO NOTHING;
INSERT INTO chatli_user (id, username, phone_number, email, password)
VALUES (gen_random_uuid(), 'ceasar', '463456', 'ceasar@example.com', 'ceasar')
ON CONFLICT DO NOTHING;
