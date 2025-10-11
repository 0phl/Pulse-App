import '../models/firestore_user.dart';

class ResidentStatisticsService {
  // Get age distribution counts for each age group
  Future<Map<String, int>> getAgeDistribution(List<FirestoreUser> users) async {
    final distribution = {
      'Children': 0,
      'Youth': 0,
      'Adults': 0,
      'Seniors': 0,
    };

    for (var user in users) {
      final group = user.ageGroup;
      distribution[group] = (distribution[group] ?? 0) + 1;
    }

    return distribution;
  }

  // Group residents by identical address strings for household identification
  Future<Map<String, List<FirestoreUser>>> groupByAddress(
      List<FirestoreUser> users) async {
    final Map<String, List<FirestoreUser>> households = {};

    for (var user in users) {
      // Normalize address for matching
      final normalizedAddress = _normalizeAddress(user.address);

      if (normalizedAddress.isEmpty) continue;

      if (!households.containsKey(normalizedAddress)) {
        households[normalizedAddress] = [];
      }
      households[normalizedAddress]!.add(user);
    }

    // Only return households with multiple members
    return Map.fromEntries(
      households.entries.where((entry) => entry.value.length > 1),
    );
  }

  // Get comprehensive resident demographics
  Future<Map<String, dynamic>> getResidentDemographics(
      List<FirestoreUser> users) async {
    final totalCount = users.length;
    final verifiedCount =
        users.where((u) => u.verificationStatus == 'verified').length;

    // Get age distribution
    final ageDistribution = await getAgeDistribution(users);

    // Get recent registrations (last 7 days)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentCount =
        users.where((u) => u.createdAt.isAfter(sevenDaysAgo)).length;

    // Calculate average age
    final totalAge = users.fold<int>(0, (sum, user) => sum + user.age);
    final averageAge = totalCount > 0 ? (totalAge / totalCount).round() : 0;

    return {
      'totalResidents': totalCount,
      'verifiedResidents': verifiedCount,
      'verificationProgress':
          totalCount > 0 ? (verifiedCount / totalCount * 100).round() : 0,
      'children': ageDistribution['Children'] ?? 0,
      'youth': ageDistribution['Youth'] ?? 0,
      'adults': ageDistribution['Adults'] ?? 0,
      'seniors': ageDistribution['Seniors'] ?? 0,
      'recentRegistrations': recentCount,
      'averageAge': averageAge,
    };
  }

  // Filter users by age group
  Future<List<FirestoreUser>> filterByAgeGroup(
      List<FirestoreUser> users, String ageGroup) async {
    if (ageGroup == 'All') {
      return users;
    }

    return users.where((user) => user.ageGroup == ageGroup).toList();
  }

  // Search by address, barangay, or municipality
  Future<List<FirestoreUser>> searchByAddress(
      List<FirestoreUser> users, String query) async {
    if (query.isEmpty) {
      return users;
    }

    final lowercaseQuery = query.toLowerCase();

    return users.where((user) {
      // Search in address
      final addressMatch = user.address.toLowerCase().contains(lowercaseQuery);

      // Search in barangay
      final barangay = user.location['barangay'] ?? '';
      final barangayMatch = barangay.toLowerCase().contains(lowercaseQuery);

      // Search in municipality
      final municipality = user.location['municipality'] ?? '';
      final municipalityMatch =
          municipality.toLowerCase().contains(lowercaseQuery);

      // Search in full address
      final fullAddressMatch =
          user.fullAddress.toLowerCase().contains(lowercaseQuery);

      return addressMatch ||
          barangayMatch ||
          municipalityMatch ||
          fullAddressMatch;
    }).toList();
  }

  // Helper method to normalize address for matching
  String _normalizeAddress(String address) {
    return address.trim().toLowerCase();
  }

  // Get household statistics
  Future<Map<String, dynamic>> getHouseholdStatistics(
      Map<String, List<FirestoreUser>> households) async {
    final totalHouseholds = households.length;
    final totalMembers =
        households.values.fold<int>(0, (sum, members) => sum + members.length);

    // Find largest household
    var largestHouseholdSize = 0;
    String? largestHouseholdAddress;

    households.forEach((address, members) {
      if (members.length > largestHouseholdSize) {
        largestHouseholdSize = members.length;
        largestHouseholdAddress = address;
      }
    });

    // Calculate average household size
    final averageHouseholdSize = totalHouseholds > 0
        ? (totalMembers / totalHouseholds).toStringAsFixed(1)
        : '0';

    return {
      'totalHouseholds': totalHouseholds,
      'totalMembers': totalMembers,
      'averageHouseholdSize': averageHouseholdSize,
      'largestHouseholdSize': largestHouseholdSize,
      'largestHouseholdAddress': largestHouseholdAddress,
    };
  }

  // Get age range for filtering UI
  List<String> getAgeFilterOptions() {
    return ['All', 'Children', 'Youth', 'Adults', 'Seniors'];
  }

  // Get detailed age breakdown
  Map<String, String> getAgeGroupDescription() {
    return {
      'Children': '0-11 years',
      'Youth': '12-17 years',
      'Adults': '18-59 years',
      'Seniors': '60+ years',
    };
  }
}
