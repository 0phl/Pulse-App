import 'package:flutter/material.dart';

class ModernShimmerLoading extends StatelessWidget {
  const ModernShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8), // Reduced vertical padding
      // Make sure the ListView doesn't try to be as big as its children
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildLoadingCard(80), // Quick actions (further reduced height)
        const SizedBox(height: 12), // Reduced spacing
        _buildLoadingCard(60), // Rating card (further reduced height)
        const SizedBox(height: 12), // Reduced spacing
        _buildLoadingCard(120), // Chart (further reduced height)
        const SizedBox(height: 12), // Reduced spacing
        _buildStatsLoadingCard(isDarkMode), // Stats card
        const SizedBox(height: 12), // Reduced spacing
        _buildItemsLoadingCard(isDarkMode), // Items card
        const SizedBox(height: 12), // Reduced spacing
        _buildListLoadingCard(isDarkMode), // Activity list
      ],
    );
  }

  Widget _buildLoadingCard(double height) {
    return Builder(builder: (context) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final baseColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

      return Container(
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(16),
        ),
      );
    });
  }

  Widget _buildStatsLoadingCard(bool isDarkMode) {
    final baseColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12), // Reduced spacing
          // Generate only 2 items instead of 3
          ...List.generate(
            2, // Reduced from 3 to 2
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8), // Reduced padding
              child: Row(
                children: [
                  Container(
                    width: 32, // Smaller size
                    height: 32, // Smaller size
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Expanded(
                    child: Container(
                      height: 12, // Smaller height
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Container(
                    width: 50, // Smaller width
                    height: 12, // Smaller height
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsLoadingCard(bool isDarkMode) {
    final baseColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12), // Reduced spacing
          // Generate only 2 items instead of 3
          ...List.generate(
            2, // Reduced from 3 to 2
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8), // Reduced padding
              child: Row(
                children: [
                  Container(
                    width: 32, // Smaller size
                    height: 32, // Smaller size
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 12, // Smaller height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4), // Reduced spacing
                        Container(
                          width: 80, // Smaller width
                          height: 8, // Smaller height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListLoadingCard(bool isDarkMode) {
    final baseColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12), // Reduced spacing
          // Generate only 2 items instead of 3
          ...List.generate(
            2, // Reduced from 3 to 2
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8), // Reduced padding
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20, // Smaller size
                    height: 20, // Smaller size
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 12, // Smaller height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4), // Reduced spacing
                        Container(
                          width: 60, // Smaller width
                          height: 8, // Smaller height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
