import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static const String baseUrl = 'https://psgc.gitlab.io/api';

  // Get all regions
  Future<List<Region>> getRegions() async {
    List<Region> regions = [];
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/regions'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        regions = data.map((json) => Region.fromJson(json)).toList();
      } else {
        print('Failed to load regions. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error loading regions from API: $e');
      print('Stack trace: $stackTrace');
    }

    // Add local data only if API call failed
    if (regions.isEmpty) {
      regions.addAll(_getLocalRegions());
    }
    
    // Remove duplicates based on code
    final uniqueRegions = regions.fold<Map<String, Region>>({}, (map, region) {
      if (region.code.isNotEmpty && region.name.isNotEmpty) {
        map[region.code] = region;
      }
      return map;
    }).values.toList();

    if (uniqueRegions.isEmpty) {
      print('Warning: No regions found after processing');
    }

    return uniqueRegions..sort((a, b) => a.name.compareTo(b.name));
  }

  // Get provinces by region code
  Future<List<Province>> getProvinces(String regionCode) async {
    List<Province> provinces = [];
    
    try {
      // Special handling for NCR
      final String endpoint = regionCode == '13' || regionCode == '130000000' 
          ? '$baseUrl/regions/130000000/districts'  // Use districts endpoint for NCR
          : '$baseUrl/regions/$regionCode/provinces';
      
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        if (regionCode == '13' || regionCode == '130000000') {
          // Convert districts to provinces for NCR
          provinces = data.map((json) => Province(
            code: json['code'] ?? json['district_code'] ?? '',
            name: (json['name'] ?? json['district_name'] ?? '').toUpperCase(),
          )).toList();
        } else {
          provinces = data.map((json) => Province.fromJson(json)).toList();
        }
      } else {
        print('Failed to load provinces/districts. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error loading provinces/districts from API: $e');
      print('Stack trace: $stackTrace');
    }

    // Add local data only if API call failed
    if (provinces.isEmpty) {
      provinces.addAll(_getLocalProvinces(regionCode));
    }
    
    // Remove duplicates based on code
    final uniqueProvinces = provinces.fold<Map<String, Province>>({}, (map, province) {
      if (province.code.isNotEmpty && province.name.isNotEmpty) {
        map[province.code] = province;
      }
      return map;
    }).values.toList();

    if (uniqueProvinces.isEmpty) {
      print('Warning: No provinces/districts found for region $regionCode');
    }

    return uniqueProvinces..sort((a, b) => a.name.compareTo(b.name));
  }

  // Get municipalities by province code
  Future<List<Municipality>> getMunicipalities(String provinceCode) async {
    List<Municipality> municipalities = [];
    
    try {
      // For NCR districts, we need to use a different endpoint
      final bool isNCRDistrict = provinceCode.startsWith('13');
      final String endpoint = isNCRDistrict
          ? '$baseUrl/districts/$provinceCode/cities-municipalities'
          : '$baseUrl/provinces/$provinceCode/cities-municipalities';

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        municipalities = data.map((json) => Municipality.fromJson(json)).toList();
      } else {
        print('Failed to load municipalities. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error loading municipalities from API: $e');
      print('Stack trace: $stackTrace');
    }

    // Add local data only if API call failed
    if (municipalities.isEmpty) {
      municipalities.addAll(_getLocalMunicipalities(provinceCode));
    }
    
    // Remove duplicates based on code
    final uniqueMunicipalities = municipalities.fold<Map<String, Municipality>>({}, (map, municipality) {
      if (municipality.code.isNotEmpty && municipality.name.isNotEmpty) {
        map[municipality.code] = municipality;
      }
      return map;
    }).values.toList();

    if (uniqueMunicipalities.isEmpty) {
      print('Warning: No municipalities found for province/district $provinceCode');
    }

    return uniqueMunicipalities..sort((a, b) => a.name.compareTo(b.name));
  }

  // Get barangays by municipality code
  Future<List<Barangay>> getBarangays(String municipalityCode) async {
    // For Bacoor City, return local data immediately
    if (municipalityCode == "042108") {
      return _getLocalBarangays(municipalityCode)
        ..sort((a, b) => a.name.compareTo(b.name));
    }

    // For other municipalities, use API data
    List<Barangay> barangays = [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cities-municipalities/$municipalityCode/barangays'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        barangays = data.map((json) => Barangay.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading barangays from API: $e');
    }

    return barangays..sort((a, b) => a.name.compareTo(b.name));
  }

  // Local data fallbacks
  List<Region> _getLocalRegions() {
    return []; // No need for local regions as API provides them
  }

  List<Province> _getLocalProvinces(String regionCode) {
    return []; // No need for local provinces as API provides them
  }

  List<Municipality> _getLocalMunicipalities(String provinceCode) {
    if (provinceCode == "0421") { // Cavite
      return [
        Municipality(code: "042108", name: "CITY OF BACOOR", isCity: true),
      ];
    }
    return [];
  }

  List<Barangay> _getLocalBarangays(String municipalityCode) {
    if (municipalityCode == "042108") { // Bacoor
      return [
        Barangay(code: "042108001", name: "ALIMA"),
        Barangay(code: "042108002", name: "ANIBAN I"),
        Barangay(code: "042108003", name: "ANIBAN II"),
        Barangay(code: "042108004", name: "ANIBAN III"),
        Barangay(code: "042108005", name: "ANIBAN IV"),
        Barangay(code: "042108006", name: "ANIBAN V"),
        Barangay(code: "042108007", name: "BANALO"),
        Barangay(code: "042108008", name: "BAYANAN"),
        Barangay(code: "042108009", name: "DAANG BUKID"),
        Barangay(code: "042108010", name: "DIGMAN"),
        Barangay(code: "042108011", name: "DULONG BAYAN"),
        Barangay(code: "042108012", name: "HABAY I"),
        Barangay(code: "042108013", name: "HABAY II"),
        Barangay(code: "042108014", name: "KAINGIN"),
        Barangay(code: "042108015", name: "LIGAS I"),
        Barangay(code: "042108016", name: "LIGAS II"),
        Barangay(code: "042108017", name: "LIGAS III"),
        Barangay(code: "042108018", name: "MABOLO I"),
        Barangay(code: "042108019", name: "MABOLO II"),
        Barangay(code: "042108020", name: "MABOLO III"),
        Barangay(code: "042108021", name: "MALIKSI I"),
        Barangay(code: "042108022", name: "MALIKSI II"),
        Barangay(code: "042108023", name: "MALIKSI III"),
        Barangay(code: "042108024", name: "MOLINO I"),
        Barangay(code: "042108025", name: "MOLINO II"),
        Barangay(code: "042108026", name: "MOLINO III"),
        Barangay(code: "042108027", name: "MOLINO IV"),
        Barangay(code: "042108028", name: "MOLINO V"),
        Barangay(code: "042108029", name: "MOLINO VI"),
        Barangay(code: "042108030", name: "MOLINO VII"),
        Barangay(code: "042108031", name: "NIOG I"),
        Barangay(code: "042108032", name: "NIOG II"),
        Barangay(code: "042108033", name: "NIOG III"),
        Barangay(code: "042108034", name: "PANAPAAN I"),
        Barangay(code: "042108035", name: "PANAPAAN II"),
        Barangay(code: "042108036", name: "PANAPAAN III"),
        Barangay(code: "042108037", name: "PANAPAAN IV"),
        Barangay(code: "042108038", name: "PANAPAAN V"),
        Barangay(code: "042108039", name: "PANAPAAN VI"),
        Barangay(code: "042108040", name: "PANAPAAN VII"),
        Barangay(code: "042108041", name: "PANAPAAN VIII"),
        Barangay(code: "042108042", name: "QUEENS ROW CENTRAL"),
        Barangay(code: "042108043", name: "QUEENS ROW EAST"),
        Barangay(code: "042108044", name: "QUEENS ROW WEST"),
        Barangay(code: "042108045", name: "REAL I"),
        Barangay(code: "042108046", name: "REAL II"),
        Barangay(code: "042108047", name: "SALINAS I"),
        Barangay(code: "042108048", name: "SALINAS II"),
        Barangay(code: "042108049", name: "SALINAS III"),
        Barangay(code: "042108050", name: "SALINAS IV"),
        Barangay(code: "042108051", name: "SAN NICOLAS I"),
        Barangay(code: "042108052", name: "SAN NICOLAS II"),
        Barangay(code: "042108053", name: "SAN NICOLAS III"),
        Barangay(code: "042108054", name: "SINEGUELASAN"),
        Barangay(code: "042108055", name: "TALABA I"),
        Barangay(code: "042108056", name: "TALABA II"),
        Barangay(code: "042108057", name: "TALABA III"),
        Barangay(code: "042108058", name: "TALABA IV"),
        Barangay(code: "042108059", name: "TALABA V"),
        Barangay(code: "042108060", name: "TALABA VI"),
        Barangay(code: "042108061", name: "TALABA VII"),
        Barangay(code: "042108062", name: "ZAPOTE I"),
        Barangay(code: "042108063", name: "ZAPOTE II"),
        Barangay(code: "042108064", name: "ZAPOTE III"),
        Barangay(code: "042108065", name: "ZAPOTE IV"),
        Barangay(code: "042108066", name: "ZAPOTE V"),
      ];
    }
    return [];
  }
}

class Region {
  final String code;
  final String name;

  Region({required this.code, required this.name});

  factory Region.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? json['region_name'] ?? '';
    final code = json['code'] ?? json['region_code'] ?? '';
    return Region(
      code: code,
      name: name.toUpperCase(),  // Ensure consistent casing
    );
  }
}

class Province {
  final String code;
  final String name;

  Province({required this.code, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? json['province_name'] ?? '';
    final code = json['code'] ?? json['province_code'] ?? '';
    return Province(
      code: code,
      name: name.toUpperCase(),  // Ensure consistent casing
    );
  }
}

class Municipality {
  final String code;
  final String name;
  final bool isCity;

  Municipality({
    required this.code, 
    required this.name, 
    this.isCity = false,
  });

  factory Municipality.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? json['city_municipality_name'] ?? '';
    final code = json['code'] ?? json['city_municipality_code'] ?? '';
    return Municipality(
      code: code,
      name: name.toUpperCase(),  // Ensure consistent casing
      isCity: name.toUpperCase().contains('CITY'),
    );
  }
}

class Barangay {
  final String code;
  final String name;

  Barangay({required this.code, required this.name});

  factory Barangay.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? json['barangay_name'] ?? '';
    final code = json['code'] ?? json['barangay_code'] ?? '';
    return Barangay(
      code: code,
      name: name.toUpperCase(),  // Ensure consistent casing
    );
  }
} 