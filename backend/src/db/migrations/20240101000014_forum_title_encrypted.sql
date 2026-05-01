-- Encrypt forum post titles: convert title column from TEXT to BYTEA so the
-- server stores opaque ciphertext and can no longer read post titles.
--
-- Existing rows will have their text re-encoded as raw bytes (UTF-8 cast).
-- After this migration every new title written by the client is an ECIES
-- ciphertext blob; old plaintext rows are a migration artefact and should be
-- deleted or re-encrypted out-of-band.
ALTER TABLE forum_posts
    ALTER COLUMN title TYPE BYTEA USING title::bytea;

COMMENT ON COLUMN forum_posts.title IS
    'ECIES ciphertext (X25519+HKDF+ChaCha20-Poly1305). Client encrypts the '
    'plaintext title before upload; the server cannot decrypt this column.';
