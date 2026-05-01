-- Enable uuid-ossp for uuid_generate_v4() and pgcrypto for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
