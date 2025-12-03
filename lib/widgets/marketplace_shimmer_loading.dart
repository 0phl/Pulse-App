import 'package:flutter/material.dart';

class MarketplaceShimmerLoading extends StatefulWidget {
  final bool isGridView;

  const MarketplaceShimmerLoading({
    super.key,
    this.isGridView = false,
  });

  @override
  State<MarketplaceShimmerLoading> createState() => _MarketplaceShimmerLoadingState();
}

class _MarketplaceShimmerLoadingState extends State<MarketplaceShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return widget.isGridView ? _buildGridShimmer(isDarkMode) : _buildListShimmer(isDarkMode);
  }

  Widget _buildGridShimmer(bool isDarkMode) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: 6, // Show 6 shimmer items
      itemBuilder: (context, index) => _buildShimmerCard(isDarkMode, isGrid: true),
    );
  }

  Widget _buildListShimmer(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4, // Show 4 shimmer items
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildShimmerCard(isDarkMode, isGrid: false),
      ),
    );
  }

  Widget _buildShimmerCard(bool isDarkMode, {required bool isGrid}) {
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Card(
      elevation: 1,
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image shimmer
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: isGrid ? 1 : 4/3,
              child: _buildShimmerBox(baseColor, highlightColor),
            ),
          ),
          // Content shimmer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title shimmer
                _buildShimmerBox(
                  baseColor,
                  highlightColor,
                  height: 20,
                  width: double.infinity,
                ),
                const SizedBox(height: 8),
                // Price shimmer
                _buildShimmerBox(
                  baseColor,
                  highlightColor,
                  height: 16,
                  width: 100,
                ),
                const SizedBox(height: 8),
                // Description shimmer (only for list view)
                if (!isGrid) ...[
                  _buildShimmerBox(
                    baseColor,
                    highlightColor,
                    height: 14,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 4),
                  _buildShimmerBox(
                    baseColor,
                    highlightColor,
                    height: 14,
                    width: 200,
                  ),
                  const SizedBox(height: 12),
                ],
                // Seller info shimmer
                Row(
                  children: [
                    // Avatar shimmer
                    _buildShimmerBox(
                      baseColor,
                      highlightColor,
                      height: 24,
                      width: 24,
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 8),
                    // Seller name shimmer
                    _buildShimmerBox(
                      baseColor,
                      highlightColor,
                      height: 14,
                      width: 80,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Button shimmer
                _buildShimmerBox(
                  baseColor,
                  highlightColor,
                  height: 36,
                  width: double.infinity,
                  borderRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBox(
    Color baseColor,
    Color highlightColor, {
    double? height,
    double? width,
    double borderRadius = 4,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [
                0.0,
                0.5,
                1.0,
              ],
              transform: GradientRotation(_animation.value),
            ),
          ),
        );
      },
    );
  }
}
