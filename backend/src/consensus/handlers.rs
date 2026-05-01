//! Consensus handlers for 2-member group member add/remove approval.

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use axum::extract::ws::Message;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::auth::middleware::AuthUser;
use crate::db::DbPool;
use crate::error::AppError;
use crate::relay::ws_handler::ConnectionMap;

// ---------------------------------------------------------------------------
// DB row types
// ---------------------------------------------------------------------------

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct MemberProposal {
    pub id: Uuid,
    pub group_id: String,
    pub action: String,
    pub target_key_hex: String,
    pub target_label: Option<String>,
    pub proposed_by: String,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub executed_at: Option<DateTime<Utc>>,
    pub state: String,
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct ProposalVote {
    pub proposal_id: Uuid,
    pub voter_key_hex: String,
    pub vote: String,
    pub voted_at: DateTime<Utc>,
}

#[derive(Debug, sqlx::FromRow)]
struct UserKeyRow {
    public_key: String,
    group_id: Option<Uuid>,
}

#[derive(Debug, sqlx::FromRow)]
struct MemberIdRow {
    id: Uuid,
}

// ---------------------------------------------------------------------------
// Request / response types
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct ProposeRequest {
    pub action: String,
    pub target_key_hex: String,
    pub target_label: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct VoteRequest {
    pub approve: bool,
}

#[derive(Debug, Serialize)]
pub struct ProposalWithVotes {
    #[serde(flatten)]
    pub proposal: MemberProposal,
    pub votes: Vec<ProposalVote>,
    pub approve_count: i64,
    pub reject_count: i64,
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async fn get_user_info(pool: &DbPool, user_id: Uuid) -> Result<UserKeyRow, AppError> {
    sqlx::query_as::<_, UserKeyRow>(
        "SELECT public_key, group_id FROM users WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(AppError::Database)?
    .ok_or_else(|| AppError::NotFound("user not found".to_string()))
}

async fn get_group_members(pool: &DbPool, group_id: Uuid) -> Result<Vec<Uuid>, AppError> {
    let rows = sqlx::query_as::<_, MemberIdRow>("SELECT id FROM users WHERE group_id = $1")
        .bind(group_id)
        .fetch_all(pool)
        .await
        .map_err(AppError::Database)?;
    Ok(rows.into_iter().map(|r| r.id).collect())
}

async fn broadcast_to_users(connections: &ConnectionMap, user_ids: &[Uuid], payload: &str) {
    let senders: Vec<_> = {
        let guard = connections.read().await;
        user_ids
            .iter()
            .filter_map(|uid| guard.get(uid).cloned().map(|tx| (*uid, tx)))
            .collect()
    };
    for (uid, tx) in senders {
        if tx.try_send(Message::Text(payload.to_string())).is_err() {
            tracing::warn!(user_id = %uid, "consensus broadcast: channel full, message dropped");
        }
    }
}

/// Re-fetch proposal state, check vote counts, execute if 2 APPROVEs or majority REJECT.
async fn check_and_execute(
    pool: &DbPool,
    connections: &ConnectionMap,
    proposal_id: Uuid,
) -> Result<(), AppError> {
    let proposal = sqlx::query_as::<_, MemberProposal>(
        "SELECT id, group_id, action, target_key_hex, target_label, proposed_by,
                created_at, expires_at, executed_at, state
         FROM member_proposals WHERE id = $1",
    )
    .bind(proposal_id)
    .fetch_optional(pool)
    .await
    .map_err(AppError::Database)?;

    let proposal = match proposal {
        Some(p) if p.state == "PENDING" => p,
        _ => return Ok(()), // already resolved or missing
    };

    let approve_count: i64 =
        sqlx::query_scalar(
            "SELECT COUNT(*) FROM proposal_votes WHERE proposal_id = $1 AND vote = 'APPROVE'",
        )
        .bind(proposal_id)
        .fetch_one(pool)
        .await
        .map_err(AppError::Database)?;

    let reject_count: i64 =
        sqlx::query_scalar(
            "SELECT COUNT(*) FROM proposal_votes WHERE proposal_id = $1 AND vote = 'REJECT'",
        )
        .bind(proposal_id)
        .fetch_one(pool)
        .await
        .map_err(AppError::Database)?;

    let group_id = match proposal.group_id.parse::<Uuid>() {
        Ok(id) => id,
        Err(_) => return Ok(()),
    };

    let total_members: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE group_id = $1")
            .bind(group_id)
            .fetch_one(pool)
            .await
            .map_err(AppError::Database)?;

    if approve_count >= 2 {
        // Execute the action.
        match proposal.action.as_str() {
            "ADD" => {
                sqlx::query(
                    "INSERT INTO public_key_allowlist (public_key_hex, added_by, label)
                     VALUES ($1, $2, $3)
                     ON CONFLICT (public_key_hex) DO UPDATE
                       SET label = EXCLUDED.label, added_by = EXCLUDED.added_by",
                )
                .bind(&proposal.target_key_hex)
                .bind(&proposal.proposed_by)
                .bind(&proposal.target_label)
                .execute(pool)
                .await
                .map_err(AppError::Database)?;
            }
            "REMOVE" => {
                sqlx::query(
                    "DELETE FROM public_key_allowlist WHERE public_key_hex = $1",
                )
                .bind(&proposal.target_key_hex)
                .execute(pool)
                .await
                .map_err(AppError::Database)?;
            }
            _ => {}
        }

        sqlx::query(
            "UPDATE member_proposals SET state = 'APPROVED', executed_at = NOW() WHERE id = $1",
        )
        .bind(proposal_id)
        .execute(pool)
        .await
        .map_err(AppError::Database)?;

        let member_ids = get_group_members(pool, group_id).await?;
        let notification = if proposal.action == "REMOVE" {
            json!({
                "type": "member_removed",
                "proposalId": proposal.id,
                "targetKeyHex": proposal.target_key_hex,
            })
        } else {
            json!({
                "type": "proposal_approved",
                "proposalId": proposal.id,
                "action": proposal.action,
                "targetKeyHex": proposal.target_key_hex,
                "targetLabel": proposal.target_label,
            })
        };
        broadcast_to_users(connections, &member_ids, &notification.to_string()).await;
    } else if total_members > 0 && reject_count > total_members / 2 {
        // Majority REJECT.
        sqlx::query(
            "UPDATE member_proposals SET state = 'REJECTED' WHERE id = $1",
        )
        .bind(proposal_id)
        .execute(pool)
        .await
        .map_err(AppError::Database)?;

        let member_ids = get_group_members(pool, group_id).await?;
        let notification = json!({
            "type": "proposal_rejected",
            "proposalId": proposal.id,
            "action": proposal.action,
            "targetKeyHex": proposal.target_key_hex,
        });
        broadcast_to_users(connections, &member_ids, &notification.to_string()).await;
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/// POST /consensus/propose — create a new member add/remove proposal.
///
/// Proposer's vote is automatically cast as APPROVE.
/// Broadcasts `{type:"proposal_created", ...}` to all online group members.
pub async fn create_proposal(
    State(pool): State<DbPool>,
    State(connections): State<ConnectionMap>,
    auth: AuthUser,
    Json(body): Json<ProposeRequest>,
) -> Result<impl IntoResponse, AppError> {
    if body.action != "ADD" && body.action != "REMOVE" {
        return Err(AppError::BadRequest(
            "action must be 'ADD' or 'REMOVE'".to_string(),
        ));
    }
    if body.target_key_hex.is_empty() {
        return Err(AppError::BadRequest("target_key_hex is required".to_string()));
    }

    let user = get_user_info(&pool, auth.user_id).await?;
    let group_id = user
        .group_id
        .ok_or_else(|| AppError::BadRequest("user is not in a group".to_string()))?;

    if user.public_key == body.target_key_hex {
        return Err(AppError::BadRequest(
            "proposer cannot be the target".to_string(),
        ));
    }

    let proposal = sqlx::query_as::<_, MemberProposal>(
        "INSERT INTO member_proposals (group_id, action, target_key_hex, target_label, proposed_by)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, group_id, action, target_key_hex, target_label, proposed_by,
                   created_at, expires_at, executed_at, state",
    )
    .bind(group_id.to_string())
    .bind(&body.action)
    .bind(&body.target_key_hex)
    .bind(&body.target_label)
    .bind(&user.public_key)
    .fetch_one(&pool)
    .await
    .map_err(AppError::Database)?;

    // Auto-cast proposer's APPROVE vote.
    sqlx::query(
        "INSERT INTO proposal_votes (proposal_id, voter_key_hex, vote)
         VALUES ($1, $2, 'APPROVE')
         ON CONFLICT DO NOTHING",
    )
    .bind(proposal.id)
    .bind(&user.public_key)
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    // Broadcast proposal_created to all online group members.
    let member_ids = get_group_members(&pool, group_id).await?;
    let notification = json!({
        "type": "proposal_created",
        "proposalId": proposal.id,
        "action": proposal.action,
        "targetKeyHex": proposal.target_key_hex,
        "targetLabel": proposal.target_label,
        "proposedBy": user.public_key,
    });
    broadcast_to_users(&connections, &member_ids, &notification.to_string()).await;

    // Check if 2 approvals already reached (e.g. single-member group in tests).
    check_and_execute(&pool, &connections, proposal.id).await?;

    Ok((StatusCode::CREATED, Json(json!({ "proposal": proposal }))))
}

/// POST /consensus/proposals/:id/vote — cast APPROVE or REJECT on a proposal.
pub async fn cast_vote(
    State(pool): State<DbPool>,
    State(connections): State<ConnectionMap>,
    auth: AuthUser,
    Path(proposal_id): Path<Uuid>,
    Json(body): Json<VoteRequest>,
) -> Result<impl IntoResponse, AppError> {
    let user = get_user_info(&pool, auth.user_id).await?;
    let group_id = user
        .group_id
        .ok_or_else(|| AppError::BadRequest("user is not in a group".to_string()))?;

    let proposal = sqlx::query_as::<_, MemberProposal>(
        "SELECT id, group_id, action, target_key_hex, target_label, proposed_by,
                created_at, expires_at, executed_at, state
         FROM member_proposals WHERE id = $1",
    )
    .bind(proposal_id)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?
    .ok_or_else(|| AppError::NotFound("proposal not found".to_string()))?;

    if proposal.state != "PENDING" {
        return Err(AppError::BadRequest(
            "proposal is no longer pending".to_string(),
        ));
    }

    if group_id.to_string() != proposal.group_id {
        return Err(AppError::Forbidden(
            "not a member of this proposal's group".to_string(),
        ));
    }

    let vote_str = if body.approve { "APPROVE" } else { "REJECT" };
    sqlx::query(
        "INSERT INTO proposal_votes (proposal_id, voter_key_hex, vote)
         VALUES ($1, $2, $3)
         ON CONFLICT (proposal_id, voter_key_hex)
         DO UPDATE SET vote = EXCLUDED.vote, voted_at = NOW()",
    )
    .bind(proposal_id)
    .bind(&user.public_key)
    .bind(vote_str)
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    check_and_execute(&pool, &connections, proposal_id).await?;

    Ok(Json(json!({ "voted": true, "vote": vote_str })))
}

/// GET /consensus/proposals — list open (PENDING) proposals for the caller's group.
pub async fn list_proposals(
    State(pool): State<DbPool>,
    auth: AuthUser,
) -> Result<impl IntoResponse, AppError> {
    let user = get_user_info(&pool, auth.user_id).await?;
    let group_id = user
        .group_id
        .ok_or_else(|| AppError::BadRequest("user is not in a group".to_string()))?;

    let proposals = sqlx::query_as::<_, MemberProposal>(
        "SELECT id, group_id, action, target_key_hex, target_label, proposed_by,
                created_at, expires_at, executed_at, state
         FROM member_proposals
         WHERE group_id = $1 AND state = 'PENDING' AND expires_at > NOW()
         ORDER BY created_at DESC",
    )
    .bind(group_id.to_string())
    .fetch_all(&pool)
    .await
    .map_err(AppError::Database)?;

    Ok(Json(json!({ "proposals": proposals })))
}

/// GET /consensus/proposals/:id — get a proposal with its vote list.
pub async fn get_proposal(
    State(pool): State<DbPool>,
    auth: AuthUser,
    Path(proposal_id): Path<Uuid>,
) -> Result<impl IntoResponse, AppError> {
    let user = get_user_info(&pool, auth.user_id).await?;
    let group_id = user
        .group_id
        .ok_or_else(|| AppError::BadRequest("user is not in a group".to_string()))?;

    let proposal = sqlx::query_as::<_, MemberProposal>(
        "SELECT id, group_id, action, target_key_hex, target_label, proposed_by,
                created_at, expires_at, executed_at, state
         FROM member_proposals WHERE id = $1",
    )
    .bind(proposal_id)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?
    .ok_or_else(|| AppError::NotFound("proposal not found".to_string()))?;

    if group_id.to_string() != proposal.group_id {
        return Err(AppError::Forbidden(
            "not a member of this proposal's group".to_string(),
        ));
    }

    let votes = sqlx::query_as::<_, ProposalVote>(
        "SELECT proposal_id, voter_key_hex, vote, voted_at
         FROM proposal_votes WHERE proposal_id = $1 ORDER BY voted_at ASC",
    )
    .bind(proposal_id)
    .fetch_all(&pool)
    .await
    .map_err(AppError::Database)?;

    let approve_count = votes.iter().filter(|v| v.vote == "APPROVE").count() as i64;
    let reject_count = votes.iter().filter(|v| v.vote == "REJECT").count() as i64;

    Ok(Json(ProposalWithVotes {
        proposal,
        votes,
        approve_count,
        reject_count,
    }))
}
