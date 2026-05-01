ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS skills TEXT[] DEFAULT '{}',
  -- skills is a plaintext array: ["cooking", "programming", "first aid"]
  -- NOT encrypted — users explicitly share these publicly within their group
  ADD COLUMN IF NOT EXISTS availability TEXT DEFAULT 'online' 
    CHECK (availability IN ('online', 'away', 'offline'));
-- BLOCKED(phase-2): availability should be driven by WS presence, not DB column
-- This column is only for "I am generally available for X" profile preference
