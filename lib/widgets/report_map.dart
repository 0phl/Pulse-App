import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

class ReportMap extends StatefulWidget {
  final void Function(LatLng, String?) onLocationSelected;
  final LatLng? initialLocation;

  const ReportMap({
    Key? key,
    required this.onLocationSelected,
    this.initialLocation,
  }) : super(key: key);

  @override
  State<ReportMap> createState() => _ReportMapState();
}

class _ReportMapState extends State<ReportMap> {
  late final MapController _mapController;
  LatLng? _selectedLocation;
  String? _address;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _selectedLocation ?? const LatLng(14.5995, 120.9842), // Manila
              zoom: 13.0,
              onTap: (_, point) async {
                setState(() {
                  _selectedLocation = point;
                  _address = 'Loading address...';
                });
                widget.onLocationSelected(point, _address);
                try {
                  List<Placemark> placemarks = await placemarkFromCoordinates(
                    point.latitude,
                    point.longitude,
                  );
                  if (placemarks.isNotEmpty) {
                    final place = placemarks.first;
                    final formattedAddress = '${place.street}, ${place.locality}, ${place.subAdministrativeArea}';
                    setState(() {
                      _address = formattedAddress;
                    });
                    widget.onLocationSelected(point, formattedAddress);
                  }
                } catch (e) {
                  setState(() {
                    _address = 'Could not fetch address';
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pulse_app',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.location_on,
                        color: const Color(0xFF00C49A),
                        size: 32,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_address != null && _selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _address!,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}