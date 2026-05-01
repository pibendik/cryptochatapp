import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../consensus_provider.dart';
import '../proposal_model.dart';

/// Displays the list of open (PENDING) member add/remove proposals.
///
/// Shows the proposer, target, current approval count, time remaining,
/// and APPROVE / REJECT action buttons.
class ProposalsScreen extends ConsumerStatefulWidget {
  const ProposalsScreen({super.key});

  @override
  ConsumerState<ProposalsScreen> createState() => _ProposalsScreenState();
}

class _ProposalsScreenState extends ConsumerState<ProposalsScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await ref.read(consensusProvider.notifier).loadProposals();
    } catch (e) {
      _showError('Failed to load proposals: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _vote(String proposalId, {required bool approve}) async {
    try {
      await ref
          .read(consensusProvider.notifier)
          .castVote(proposalId, approve: approve);
      _showSnackBar(approve ? 'Vote: APPROVE cast ✓' : 'Vote: REJECT cast ✓');
    } catch (e) {
      _showError('Failed to cast vote: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposals = ref.watch(consensusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Proposals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : proposals.isEmpty
              ? const Center(
                  child: Text(
                    'No open proposals.\nPropose adding or removing a member from the members screen.',
                    textAlign: TextAlign.center,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: proposals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ProposalCard(
                      proposal: proposals[i],
                      onApprove: () =>
                          _vote(proposals[i].id, approve: true),
                      onReject: () =>
                          _vote(proposals[i].id, approve: false),
                    ),
                  ),
                ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onApprove,
    required this.onReject,
  });

  final MemberProposal proposal;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _formatTimeRemaining(Duration d) {
    if (d.isNegative) return 'Expired';
    if (d.inHours > 1) return '${d.inHours}h remaining';
    return '${d.inMinutes}m remaining';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAdd = proposal.action == 'ADD';
    final remaining = proposal.timeRemaining;
    final targetName = proposal.targetLabel ??
        '${proposal.targetKeyHex.substring(0, 8)}…';
    final proposerShort =
        '${proposal.proposedBy.substring(0, 8)}…';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  isAdd ? Icons.person_add : Icons.person_remove,
                  color: isAdd ? colors.primary : colors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAdd
                        ? 'Propose ADD: $targetName'
                        : 'Propose REMOVE: $targetName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  _formatTimeRemaining(remaining),
                  style: TextStyle(
                    fontSize: 12,
                    color: remaining.inHours < 4
                        ? colors.error
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Key hex ─────────────────────────────────────────────────
            Text(
              'Key: ${proposal.targetKeyHex}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Proposed by: $proposerShort',
              style:
                  TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            // ── Vote count ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.how_to_vote, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${proposal.approveCount}/2 approvals',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: proposal.approveCount >= 2
                        ? colors.primary
                        : null,
                  ),
                ),
                if (proposal.rejectCount > 0) ...[
                  const SizedBox(width: 16),
                  Text(
                    '${proposal.rejectCount} reject(s)',
                    style: TextStyle(color: colors.error),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // ── Action buttons ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: Icon(Icons.close, size: 18, color: colors.error),
                    label: Text('Reject',
                        style: TextStyle(color: colors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
