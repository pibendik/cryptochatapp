CREATE TABLE mls_key_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_public_key_hex TEXT NOT NULL REFERENCES public_key_allowlist(public_key_hex),
  group_id TEXT NOT NULL,
  key_package_data BYTEA NOT NULL,      -- opaque MLS KeyPackage blob
  epoch BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days',
  UNIQUE(owner_public_key_hex, group_id)
);

CREATE TABLE mls_commits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id TEXT NOT NULL,
  epoch BIGINT NOT NULL,
  commit_data BYTEA NOT NULL,           -- serialised MLS Commit message
  created_by TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
