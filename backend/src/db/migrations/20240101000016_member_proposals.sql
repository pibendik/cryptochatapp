CREATE TABLE member_proposals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id TEXT NOT NULL,
  action TEXT NOT NULL,           -- 'ADD' | 'REMOVE'
  target_key_hex TEXT NOT NULL,   -- public key of person to add/remove
  target_label TEXT,              -- human-readable name
  proposed_by TEXT NOT NULL,      -- public_key_hex of proposer
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '48 hours',
  executed_at TIMESTAMPTZ,
  state TEXT NOT NULL DEFAULT 'PENDING'  -- PENDING | APPROVED | REJECTED | EXPIRED
);

CREATE TABLE proposal_votes (
  proposal_id UUID REFERENCES member_proposals(id) ON DELETE CASCADE,
  voter_key_hex TEXT NOT NULL,
  vote TEXT NOT NULL,             -- 'APPROVE' | 'REJECT'
  voted_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (proposal_id, voter_key_hex)
);
