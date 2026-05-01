ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id);
-- Backfill not needed for empty dev DB
-- Add index for group-scoped queries
CREATE INDEX IF NOT EXISTS idx_forum_posts_group_id ON forum_posts(group_id, created_at DESC);

ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT '';
