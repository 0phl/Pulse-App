import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/community_notice.dart';
import '../../services/community_notice_service.dart';

class PollWidget extends StatefulWidget {
  final CommunityNotice notice;

  const PollWidget({super.key, required this.notice});

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  final CommunityNoticeService _noticeService = CommunityNoticeService();
  bool _isVoting = false;
  String? _currentUserId;

  String _formatExpiryDate(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative) {
      return 'Poll ended';
    }

    if (difference.inDays > 7) {
      // For dates more than a week away, show "ends in X weeks"
      final weeks = (difference.inDays / 7).floor();
      return 'Ends in ${weeks == 1 ? '1 week' : '$weeks weeks'}';
    } else if (difference.inDays > 0) {
      // For dates within a week, show "ends in X days"
      return 'Ends in ${difference.inDays == 1 ? '1 day' : '${difference.inDays} days'}';
    } else if (difference.inHours > 0) {
      return 'Ends in ${difference.inHours == 1 ? '1 hour' : '${difference.inHours} hours'}';
    } else if (difference.inMinutes > 0) {
      return 'Ends in ${difference.inMinutes == 1 ? '1 minute' : '${difference.inMinutes} minutes'}';
    } else {
      return 'Ends in ${difference.inSeconds == 1 ? '1 second' : '${difference.inSeconds} seconds'}';
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _vote(String optionId) async {
    if (_currentUserId == null || _isVoting) return;

    setState(() => _isVoting = true);

    try {
      await _noticeService.voteOnPoll(
        widget.notice.id,
        optionId,
        _currentUserId!,
        allowMultipleChoices: widget.notice.poll!.allowMultipleChoices,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error voting: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  bool _hasVoted(PollOption option) {
    return _currentUserId != null && option.votedBy.contains(_currentUserId);
  }

  bool _isPollExpired() {
    return DateTime.now().isAfter(widget.notice.poll!.expiresAt);
  }

  int _getTotalVotes() {
    return widget.notice.poll!.options
        .fold(0, (sum, option) => sum + option.voteCount);
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.notice.poll!;
    final totalVotes = _getTotalVotes();
    final isPollExpired = _isPollExpired();
    const appThemeColor = Color(0xFF00C49A);
    final hasImages =
        (widget.notice.imageUrls != null && widget.notice.imageUrls!.isNotEmpty) ||
        (widget.notice.poll!.imageUrls != null && widget.notice.poll!.imageUrls!.isNotEmpty);

    // If this poll has images and is displayed in the combined container,
    // we need a simpler layout without duplicate headers
    if (hasImages) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          ...poll.options.map((option) {
            final hasVoted = _hasVoted(option);
            final percentage = totalVotes > 0
                ? (option.voteCount / totalVotes * 100).round()
                : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap:
                    isPollExpired || _isVoting ? null : () => _vote(option.id),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: hasVoted
                        ? appThemeColor.withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasVoted ? appThemeColor : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasVoted)
                            Container(
                              padding: const EdgeInsets.all(2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: appThemeColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasVoted
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color:
                                    hasVoted ? appThemeColor : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasVoted
                                  ? appThemeColor
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$percentage%',
                              style: TextStyle(
                                color: hasVoted ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutQuart,
                            height: 6,
                            width: MediaQuery.of(context).size.width *
                                percentage /
                                100 *
                                0.7,
                            decoration: BoxDecoration(
                              color: hasVoted
                                  ? appThemeColor
                                  : appThemeColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (isPollExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off,
                          size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Poll ended',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 20, color: appThemeColor),
                            SizedBox(width: 8),
                            Text('Poll End Date'),
                          ],
                        ),
                        content: Text(
                          DateFormat('MMMM d, y h:mm a')
                              .format(poll.expiresAt.toLocal()),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close',
                                style: TextStyle(color: appThemeColor)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: appThemeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 12, color: appThemeColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatExpiryDate(poll.expiresAt),
                          style: const TextStyle(
                            color: appThemeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (poll.allowMultipleChoices) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Multiple choices allowed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Standard poll display without images
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined, color: appThemeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...poll.options.map((option) {
            final hasVoted = _hasVoted(option);
            final percentage = totalVotes > 0
                ? (option.voteCount / totalVotes * 100).round()
                : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap:
                    isPollExpired || _isVoting ? null : () => _vote(option.id),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: hasVoted
                        ? appThemeColor.withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasVoted ? appThemeColor : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasVoted)
                            Container(
                              padding: const EdgeInsets.all(2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: appThemeColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasVoted
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color:
                                    hasVoted ? appThemeColor : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasVoted
                                  ? appThemeColor
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$percentage%',
                              style: TextStyle(
                                color: hasVoted ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutQuart,
                            height: 6,
                            width: MediaQuery.of(context).size.width *
                                percentage /
                                100 *
                                0.7,
                            decoration: BoxDecoration(
                              color: hasVoted
                                  ? appThemeColor
                                  : appThemeColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (isPollExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off,
                          size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Poll ended',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 20, color: appThemeColor),
                            SizedBox(width: 8),
                            Text('Poll End Date'),
                          ],
                        ),
                        content: Text(
                          DateFormat('MMMM d, y h:mm a')
                              .format(poll.expiresAt.toLocal()),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close',
                                style: TextStyle(color: appThemeColor)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: appThemeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 12, color: appThemeColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatExpiryDate(poll.expiresAt),
                          style: const TextStyle(
                            color: appThemeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (poll.allowMultipleChoices) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Multiple choices allowed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
