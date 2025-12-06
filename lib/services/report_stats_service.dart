import '../services/admin_service.dart';

class ReportStatsService {
  final AdminService _adminService = AdminService();
  
  Future<Map<String, dynamic>> getDetailedReportStats() async {
    final reportStats = await _adminService.getReportStats();
    
    final statusCounts = reportStats['statusCounts'] as Map<String, dynamic>;
    
    final totalReports = statusCounts['total'] ?? 0;
    
    final resolvedCount = statusCounts['resolved'] ?? 0;
    final pendingCount = statusCounts['pending'] ?? 0;
    final inProgressCount = statusCounts['in_progress'] ?? 0;
    final rejectedCount = statusCounts['rejected'] ?? 0;
    
    double resolutionRate = 0;
    if (totalReports > 0) {
      resolutionRate = (resolvedCount / totalReports) * 100;
    }
    
    // Format the average resolution time
    final avgResolutionTime = reportStats['avgResolutionTime'] ?? '0';
    
    return {
      'totalReports': totalReports,
      'resolvedCount': resolvedCount,
      'pendingCount': pendingCount,
      'inProgressCount': inProgressCount,
      'rejectedCount': rejectedCount,
      'resolutionRate': resolutionRate.toStringAsFixed(1),
      'avgResolutionTime': avgResolutionTime,
    };
  }
}
