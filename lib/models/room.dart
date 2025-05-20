// lib/models/room.dart
enum RoomType { indoor, outdoor }

class Room {
  final String id;
  final String name;
  final RoomType type;
  final List<Light> lights;
  final String? createdBy;
  final DateTime? createdAt;

  Room({
    required this.id,
    required this.name,
    required this.type,
    required this.lights,
    this.createdBy,
    this.createdAt,
  });

  // Factory constructor for Firestore
  factory Room.fromMap(Map<String, dynamic> map, String id) {
    return Room(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] == 'indoor' ? RoomType.indoor : RoomType.outdoor,
      lights: (map['lights'] as List?)
              ?.map((light) => Light.fromMap(light))
              .toList() ??
          [],
      createdBy: map['createdBy'],
      createdAt: map['createdAt'] != null ? (map['createdAt']).toDate() : null,
    );
  }

  // Factory constructor for Realtime Database
  factory Room.fromRTDB(Map<String, dynamic> map, String id) {
    // Parse lights map to list for RTDB format
    final List<Light> lightsList = [];
    
    if (map['lights'] is Map) {
      final lightsMap = map['lights'] as Map;
      
      lightsMap.forEach((key, value) {
        if (value is Map) {
          final Map<String, dynamic> lightData = Map<String, dynamic>.from(value);
          lightsList.add(Light.fromMap(lightData));
        }
      });
    }
    
    // Parse timestamp if available
    DateTime? createdTimestamp;
    if (map['createdAt'] != null && map['createdAt'] is num) {
      try {
        createdTimestamp = DateTime.fromMillisecondsSinceEpoch(
            (map['createdAt'] as num).toInt());
      } catch (e) {
        print('Error parsing RTDB timestamp: $e');
      }
    }

    return Room(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] == 'indoor' ? RoomType.indoor : RoomType.outdoor,
      lights: lightsList,
      createdBy: map['createdBy'],
      createdAt: createdTimestamp,
    );
  }
  
  // Convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type == RoomType.indoor ? 'indoor' : 'outdoor',
      'lights': lights.map((light) => light.toMap()).toList(),
      'createdBy': createdBy,
    };
  }
  
  // Convert to Realtime Database Map
  Map<String, dynamic> toRTDBMap() {
    // Convert lights list to map for RTDB
    final Map<String, dynamic> lightsMap = {};
    for (final light in lights) {
      lightsMap[light.id] = light.toMap();
    }
    
    return {
      'name': name,
      'type': type == RoomType.indoor ? 'indoor' : 'outdoor',
      'lights': lightsMap,
      'createdBy': createdBy,
    };
  }
}

class Light {
  final String id;
  final String name;
  final bool isOn;
  final int brightness;
  final bool hasSchedule;
  final String? onTime;
  final String? offTime;
  final bool hasMotionSensor;
  final bool motionSensorActive;

  Light({
    required this.id,
    required this.name,
    required this.isOn,
    required this.brightness,
    this.hasSchedule = false,
    this.onTime,
    this.offTime,
    this.hasMotionSensor = false,
    this.motionSensorActive = false,
  });

  factory Light.fromMap(Map<String, dynamic> map) {
    return Light(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isOn: map['isOn'] ?? false,
      brightness: map['brightness'] ?? 100,
      hasSchedule: map['hasSchedule'] ?? false,
      onTime: map['onTime'],
      offTime: map['offTime'],
      hasMotionSensor: map['hasMotionSensor'] ?? false,
      motionSensorActive: map['motionSensorActive'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isOn': isOn,
      'brightness': brightness,
      'hasSchedule': hasSchedule,
      'onTime': onTime,
      'offTime': offTime,
      'hasMotionSensor': hasMotionSensor,
      'motionSensorActive': motionSensorActive,
    };
  }
}