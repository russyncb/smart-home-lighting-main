// lib/screens/room_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:illumi_home/models/room.dart';
import 'package:illumi_home/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  
  const RoomDetailScreen({
    super.key,
    required this.room,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late Room _room;
  StreamSubscription? _roomSubscription;
  
  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _subscribeToRoomUpdates();
  }
  
  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToRoomUpdates() {
    // Subscribe to real-time updates for this specific room
    _roomSubscription?.cancel();
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    _roomSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('rooms')
        .doc(_room.id)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            final data = snapshot.data() as Map<String, dynamic>;
            _room = Room.fromMap(data, _room.id);
          });
        }
      },
      onError: (e) {
        print('Error in room subscription: $e');
      },
    );
  }
  
  Future<void> _toggleLight(String lightId, bool newState) async {
    // Find the light
    final lightIndex = _room.lights.indexWhere((l) => l.id == lightId);
    if (lightIndex == -1) return;

    // Create a new list of lights with the updated light
    final updatedLights = List<Light>.from(_room.lights);
    final oldLight = updatedLights[lightIndex];
    
    // Replace the light with a new instance that has the updated state
    updatedLights[lightIndex] = Light(
      id: oldLight.id,
      name: oldLight.name,
      isOn: newState, // This is the change
      brightness: oldLight.brightness,
      hasMotionSensor: oldLight.hasMotionSensor,
      motionSensorActive: oldLight.motionSensorActive,
      hasSchedule: oldLight.hasSchedule,
      onTime: oldLight.onTime,
      offTime: oldLight.offTime,
    );
    
    // Create a new room with the updated lights
    final updatedRoom = Room(
      id: _room.id,
      name: _room.name,
      type: _room.type,
      lights: updatedLights,
    );
    
    // Update UI immediately
    setState(() {
      _room = updatedRoom;
    });
    
    try {
      // Update database in background
      await _databaseService.toggleLight(
        _room.id,
        lightId,
        newState
      );
    } catch (e) {
      // If error, revert to previous state
      if (mounted) {
        setState(() {
          // Revert back to original room
          _room = widget.room;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling light: $e')),
        );
      }
    }
  }
  
  Future<void> _adjustBrightness(String lightId, double brightness) async {
    // Find the light
    final lightIndex = _room.lights.indexWhere((l) => l.id == lightId);
    if (lightIndex == -1) return;

    // Get current light
    final oldLight = _room.lights[lightIndex];
    final brightnessValue = brightness.toInt();
    
    // Create a new list of lights with the updated light
    final updatedLights = List<Light>.from(_room.lights);
    
    // Replace the light with a new instance that has the updated brightness
    updatedLights[lightIndex] = Light(
      id: oldLight.id,
      name: oldLight.name,
      isOn: oldLight.isOn,
      brightness: brightnessValue, // This is the change
      hasMotionSensor: oldLight.hasMotionSensor,
      motionSensorActive: oldLight.motionSensorActive,
      hasSchedule: oldLight.hasSchedule,
      onTime: oldLight.onTime,
      offTime: oldLight.offTime,
    );
    
    // Create a new room with the updated lights
    final updatedRoom = Room(
      id: _room.id,
      name: _room.name,
      type: _room.type,
      lights: updatedLights,
    );
    
    // Update UI immediately
    setState(() {
      _room = updatedRoom;
    });
    
    try {
      // Update database in background
      await _databaseService.adjustBrightness(
        _room.id,
        lightId,
        brightnessValue
      );
    } catch (e) {
      // If error, revert to previous state
      if (mounted) {
        setState(() {
          // Revert back to original state
          final originalLights = List<Light>.from(_room.lights);
          originalLights[lightIndex] = oldLight;
          
          _room = Room(
            id: _room.id,
            name: _room.name,
            type: _room.type,
            lights: originalLights,
          );
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adjusting brightness: $e')),
        );
      }
    }
  }
  
  Future<void> _toggleMotionSensor(String lightId, bool active) async {
    // Find the light
    final lightIndex = _room.lights.indexWhere((l) => l.id == lightId);
    if (lightIndex == -1) return;

    // Get current light
    final oldLight = _room.lights[lightIndex];
    
    // Create a new list of lights with the updated light
    final updatedLights = List<Light>.from(_room.lights);
    
    // Replace the light with a new instance that has the updated motion sensor state
    updatedLights[lightIndex] = Light(
      id: oldLight.id,
      name: oldLight.name,
      isOn: oldLight.isOn,
      brightness: oldLight.brightness,
      hasMotionSensor: oldLight.hasMotionSensor,
      motionSensorActive: active, // This is the change
      hasSchedule: oldLight.hasSchedule,
      onTime: oldLight.onTime,
      offTime: oldLight.offTime,
    );
    
    // Create a new room with the updated lights
    final updatedRoom = Room(
      id: _room.id,
      name: _room.name,
      type: _room.type,
      lights: updatedLights,
    );
    
    // Update UI immediately
    setState(() {
      _room = updatedRoom;
    });
    
    try {
      // Update database in background
      await _databaseService.toggleMotionSensor(
        _room.id,
        lightId,
        active
      );
    } catch (e) {
      // If error, revert to previous state
      if (mounted) {
        setState(() {
          // Revert back to original state
          final originalLights = List<Light>.from(_room.lights);
          originalLights[lightIndex] = oldLight;
          
          _room = Room(
            id: _room.id,
            name: _room.name,
            type: _room.type,
            lights: originalLights,
          );
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling motion sensor: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _room.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _room.lights.length,
          itemBuilder: (context, index) {
            final light = _room.lights[index];
            return Card(
              color: const Color(0xFF1E293B).withOpacity(0.5),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade800),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: light.isOn
                                    ? Colors.amber.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lightbulb,
                                color: light.isOn ? Colors.amber : Colors.grey.shade500,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  light.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  light.isOn ? 'On' : 'Off',
                                  style: TextStyle(
                                    color: light.isOn ? Colors.amber : Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: light.isOn,
                          onChanged: (value) => _toggleLight(light.id, value),
                          activeColor: Colors.amber,
                          inactiveTrackColor: Colors.grey.shade700,
                        ),
                      ],
                    ),
                    
                    // Brightness slider
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.brightness_low,
                          color: Colors.white70,
                          size: 20,
                        ),
                        Expanded(
                          child: Slider(
                            value: light.brightness.toDouble(),
                            min: 1,
                            max: 100,
                            divisions: 10,
                            activeColor: Colors.amber,
                            inactiveColor: Colors.grey.shade700,
                            label: '${light.brightness}%',
                            onChanged: light.isOn
                                ? (value) => _adjustBrightness(light.id, value)
                                : null,
                          ),
                        ),
                        const Icon(
                          Icons.brightness_high,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                    
                    // Show schedule settings if applicable
                    if (light.hasSchedule) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Scheduled: On at ${light.onTime}, Off at ${light.offTime}',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Show motion sensor settings if applicable
                    if (light.hasMotionSensor) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.sensors,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Motion Sensor',
                                style: TextStyle(
                                  color: Colors.grey.shade300,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: light.motionSensorActive,
                            onChanged: (value) => _toggleMotionSensor(light.id, value),
                            activeColor: Colors.amber,
                            inactiveTrackColor: Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}