//! 2-member consensus for group member add/remove.
//!
//! Any existing group member can propose adding or removing a member.
//! The proposal is automatically given the proposer's APPROVE vote.
//! When 2 APPROVE votes are cast, the action executes (allowlist insert/delete).
//! A majority of REJECT votes closes the proposal as REJECTED.
//! Proposals expire after 48 hours if no decision is reached.

pub mod handlers;
