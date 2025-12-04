import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/community_notice.dart';

/// Widget that renders a professional shareable card for community notices
/// This widget is converted to an image for social media sharing
class ShareCardWidget extends StatelessWidget {
  final CommunityNotice notice;

  const ShareCardWidget({
    super.key,
    required this.notice,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 1080, // Instagram/Facebook optimal width
        constraints: const BoxConstraints(
          maxHeight: 1920, // Prevent overflow
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main content (header removed)
            _buildContent(),
            
            // Footer with branding
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Flexible(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(
            maxHeight: 1600, // Prevent content overflow
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C49A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'COMMUNITY NOTICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
          
              const SizedBox(height: 20),
              
              // Title
              Text(
                notice.title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 18),
          
              // Author and date
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF00C49A).withOpacity(0.15),
                    backgroundImage: notice.authorAvatar != null
                        ? CachedNetworkImageProvider(notice.authorAvatar!)
                        : null,
                    child: notice.authorAvatar == null
                        ? Text(
                            notice.authorName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF00C49A),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.authorName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          DateFormat('MMMM d, y').format(notice.createdAt),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Full content (no truncation since it's an image)
              Text(
                notice.content,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF2A2A2A),
                ),
                maxLines: 15, // Show more lines
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 20),
          
              // Image if available
              if (notice.imageUrls != null && notice.imageUrls!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: notice.imageUrls!.first,
                    height: 350,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 350,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00C49A),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 350,
                      color: Colors.grey.shade100,
                      child: Icon(Icons.image_outlined, size: 50, color: Colors.grey.shade400),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
          
              // Poll info if present
              if (notice.poll != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C49A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.poll_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Poll Included',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        notice.poll!.question,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      ...notice.poll!.options.take(3).map((option) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00C49A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  option.text,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF2A2A2A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (notice.poll!.options.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${notice.poll!.options.length - 3} more options',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
          
              // Engagement stats
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(Icons.favorite_border, notice.likesCount.toString(), 'Likes'),
                    Container(width: 1, height: 30, color: Colors.grey.shade300),
                    _buildStat(Icons.chat_bubble_outline, notice.commentsCount.toString(), 'Comments'),
                    if (notice.poll != null) ...[
                      Container(width: 1, height: 30, color: Colors.grey.shade300),
                      _buildStat(
                        Icons.how_to_vote_outlined,
                        notice.poll!.options.fold(0, (sum, opt) => sum + opt.voteCount).toString(),
                        'Votes',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF666666), size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00C49A).withOpacity(0.2),
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF00C49A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'PULSE Community Engagement Platform',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF00C49A),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  String _truncateContent(String content, int maxLength) {
    if (content.length <= maxLength) {
      return content;
    }
    
    final truncateAt = content.lastIndexOf(' ', maxLength);
    if (truncateAt == -1) {
      return '${content.substring(0, maxLength)}...';
    }
    
    return '${content.substring(0, truncateAt)}...';
  }
}