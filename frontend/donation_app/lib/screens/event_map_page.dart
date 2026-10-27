
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class EventMapPage extends StatefulWidget {
  const EventMapPage({
    super.key,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  final String location;
  final double latitude;
  final double longitude;

  @override
  State<EventMapPage> createState() => _EventMapPageState();
}

class _EventMapPageState extends State<EventMapPage> {
  late LatLng selectedPoint;
  bool locationConfirmed = true;

  @override
  void initState() {
    super.initState();
    selectedPoint = LatLng(
      widget.latitude,
      widget.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: const Text('Үйл ажиллагааны байршил'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: selectedPoint,
                initialZoom: 15,
                onTap: (tapPosition, point) {
                  setState(() {
                    selectedPoint = point;
                    locationConfirmed = false;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.donation_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedPoint,
                      width: 55,
                      height: 55,
                      child: const Icon(
                        Icons.location_pin,
                        color: Color(0xFF4389F5),
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Үйл ажиллагаа болох газар',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.location),
                const SizedBox(height: 12),
                Text(
                  'Өргөрөг: ${selectedPoint.latitude.toStringAsFixed(6)}\n'
                  'Уртраг: ${selectedPoint.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: locationConfirmed,
                  title: const Text('Байршлыг баталгаажуулсан'),
                  onChanged: (value) {
                    setState(() {
                      locationConfirmed = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: locationConfirmed
                        ? () => Navigator.pop(
                              context,
                              selectedPoint,
                            )
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Байршлыг сонгох'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
