// lib/services/realtime_db_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:illumi_home/models/room.dart';

/// A dedicated service for Firebase Realtime Database operations
/// This service handles all communication with IoT devices (NodeMCU/Arduino)
class RealtimeDBService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final DatabaseReference _roomsRef;
  final DatabaseReference _devicesRef;
  final DatabaseReference _commandsRef;
  
  RealtimeDBService() 
      : _roomsRef = FirebaseDatabase.instance.ref().child('rooms'),
        _devicesRef = FirebaseDatabase.instance.ref().child('devices'),
        _commandsRef = FirebaseDatabase.instance.ref().child('commands');
  
  // Get real-time stream of rooms for IoT devices
  Stream<List<Room>> getRoomsStream() {
    return _roomsRef.onValue.map((event) {
      print("RTDB update received: ${event.snapshot.children.length} rooms");
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      if (data == null) return [];
      
      List<Room> rooms = [];
      data.forEach((key, value) {
        if (value is Map) {
          // Convert to the correct format
          final Map<String, dynamic> roomData = Map<String, dynamic>.from(value);
          final room = Room.fromMap(roomData, key.toString());
          
          // Debug log to track light states
          final activeLights = room.lights.where((l) => l.isOn).length;
          print("Room ${room.name}: $activeLights of ${room.lights.length} lights active");
          
          rooms.add(room);
        }
      });
      
      return rooms;
    });
  }
  
  // Get a single room
  Future<Room?> getRoom(String roomId) async {
    try {
      final snapshot = await _roomsRef.child(roomId).get();
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map;
        return Room.fromMap(Map<String, dynamic>.from(data), roomId);
      }
      return null;
    } catch (e) {
      print('Error getting room from RTDB: $e');
      return null;
    }
  }
  
  // Add a room to Realtime Database (for IoT)
  Future<void> addRoom(Map<String, dynamic> roomData, String roomId) async {
    try {
      // Convert the array-based lights to map-based for RTDB
      final Map<String, dynamic> convertedData = {...roomData};
      
      // Handle timestamp format for RTDB
      convertedData['createdAt'] = ServerValue.timestamp;
      
      // Convert lights from array to map
      if (roomData['lights'] is List) {
        final Map<String, dynamic> lightsMap = {};
        final List<dynamic> lightsArray = roomData['lights'] as List;
        
        for (final light in lightsArray) {
          if (light is Map && light['id'] != null) {
            lightsMap[light['id']] = light;
          }
        }
        
        convertedData['lights'] = lightsMap;
      }
      
      // Add to RTDB using the same document ID as Firestore
      await _roomsRef.child(roomId).set(convertedData);
      
      print('Room added to Realtime Database: $roomId');
    } catch (e) {
      print('Error adding room to RTDB: $e');
      rethrow;
    }
  }
  
  // Delete a room from Realtime Database
  Future<void> deleteRoom(String roomId) async {
    try {
      await _roomsRef.child(roomId).remove();
      print('Room deleted from Realtime Database: $roomId');
    } catch (e) {
      print('Error deleting room from RTDB: $e');
      rethrow;
    }
  }
  
  // Toggle a light on/off
  Future<String> toggleLight(String roomId, String lightId, bool newState) async {
    try {
      final lightRef = _roomsRef.child(roomId).child('lights').child(lightId);
      final lightSnapshot = await lightRef.get();
      
      if (!lightSnapshot.exists) {
        throw Exception('Light not found in RTDB');
      }
      
      String lightName = "Unknown";
      if (lightSnapshot.value != null) {
        final Map<dynamic, dynamic> lightData = lightSnapshot.value as Map;
        lightName = lightData['name'] ?? "Unknown";
      }
      
      // Update the light state
      await lightRef.update({
        'isOn': newState,
      });
      
      // Also send a command to any connected IoT device
      await _sendLightCommand(roomId, lightId, newState);
      
      return lightName;
    } catch (e) {
      print('Error toggling light in RTDB: $e');
      rethrow;
    }
  }
  
  // Toggle all lights in a room
  Future<void> toggleAllLightsInRoom(String roomId, bool newState) async {
    try {
      final roomRef = _roomsRef.child(roomId);
      final roomSnapshot = await roomRef.get();
      
      if (!roomSnapshot.exists) {
        throw Exception('Room not found in RTDB');
      }
      
      final Map<dynamic, dynamic> roomData = roomSnapshot.value as Map;
      if (roomData['lights'] is Map) {
        final Map<dynamic, dynamic> lights = roomData['lights'] as Map;
        
        // Update each light
        for (final entry in lights.entries) {
          final String lightId = entry.key.toString();
          await roomRef.child('lights').child(lightId).update({
            'isOn': newState,
          });
          
          // Also send commands to IoT devices
          await _sendLightCommand(roomId, lightId, newState);
        }
      }
    } catch (e) {
      print('Error toggling all lights in RTDB: $e');
      rethrow;
    }
  }
  
  // Adjust light brightness
  Future<String> adjustBrightness(String roomId, String lightId, int brightness) async {
    try {
      final lightRef = _roomsRef.child(roomId).child('lights').child(lightId);
      final lightSnapshot = await lightRef.get();
      
      if (!lightSnapshot.exists) {
        throw Exception('Light not found in RTDB');
      }
      
      String lightName = "Unknown";
      if (lightSnapshot.value != null) {
        final Map<dynamic, dynamic> lightData = lightSnapshot.value as Map;
        lightName = lightData['name'] ?? "Unknown";
      }
      
      // Update the brightness
      await lightRef.update({
        'brightness': brightness,
      });
      
      // Send command to IoT device
      await _sendBrightnessCommand(roomId, lightId, brightness);
      
      return lightName;
    } catch (e) {
      print('Error adjusting brightness in RTDB: $e');
      rethrow;
    }
  }
  
  // Toggle motion sensor
  Future<String> toggleMotionSensor(String roomId, String lightId, bool active) async {
    try {
      final lightRef = _roomsRef.child(roomId).child('lights').child(lightId);
      final lightSnapshot = await lightRef.get();
      
      if (!lightSnapshot.exists) {
        throw Exception('Light not found in RTDB');
      }
      
      String lightName = "Unknown";
      if (lightSnapshot.value != null) {
        final Map<dynamic, dynamic> lightData = lightSnapshot.value as Map;
        lightName = lightData['name'] ?? "Unknown";
      }
      
      // Update the motion sensor state
      await lightRef.update({
        'motionSensorActive': active,
      });
      
      // Send command to IoT device
      await _sendMotionSensorCommand(roomId, lightId, active);
      
      return lightName;
    } catch (e) {
      print('Error toggling motion sensor in RTDB: $e');
      rethrow;
    }
  }

  // IoT DEVICE COMMUNICATION METHODS
  
  // Send a command to a light through connected device
  Future<void> _sendLightCommand(String roomId, String lightId, bool state) async {
    try {
      // Get device mapping for this light
      final deviceId = await _getDeviceForLight(lightId);
      
      if (deviceId != null) {
        // Send command to the device
        await _commandsRef.child(deviceId).set({
          'command': 'toggle_light',
          'params': {
            'light_id': lightId,
            'state': state ? 1 : 0,
          },
          'timestamp': ServerValue.timestamp,
          'processed': false,
        });
        
        print('Light command sent to device $deviceId');
      }
    } catch (e) {
      print('Error sending light command: $e');
    }
  }
  
  // Send brightness command to device
  Future<void> _sendBrightnessCommand(String roomId, String lightId, int brightness) async {
    try {
      // Get device mapping for this light
      final deviceId = await _getDeviceForLight(lightId);
      
      if (deviceId != null) {
        // Send command to the device
        await _commandsRef.child(deviceId).set({
          'command': 'set_brightness',
          'params': {
            'light_id': lightId,
            'brightness': brightness,
          },
          'timestamp': ServerValue.timestamp,
          'processed': false,
        });
        
        print('Brightness command sent to device $deviceId');
      }
    } catch (e) {
      print('Error sending brightness command: $e');
    }
  }
  
  // Send motion sensor command to device
  Future<void> _sendMotionSensorCommand(String roomId, String lightId, bool active) async {
    try {
      // Get device mapping for this light
      final deviceId = await _getDeviceForLight(lightId);
      
      if (deviceId != null) {
        // Send command to the device
        await _commandsRef.child(deviceId).set({
          'command': 'toggle_motion_sensor',
          'params': {
            'light_id': lightId,
            'enabled': active ? 1 : 0,
          },
          'timestamp': ServerValue.timestamp,
          'processed': false,
        });
        
        print('Motion sensor command sent to device $deviceId');
      }
    } catch (e) {
      print('Error sending motion sensor command: $e');
    }
  }
  
  // Get the device ID that controls a specific light
  Future<String?> _getDeviceForLight(String lightId) async {
    try {
      final snapshot = await _rtdb.ref().child('light_mappings').child(lightId).get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map;
        return data['device_id'] as String?;
      }
      
      return null;
    } catch (e) {
      print('Error getting device for light: $e');
      return null;
    }
  }
  
  // DEVICE MANAGEMENT METHODS
  
  // Register a new IoT device
  Future<void> registerDevice(String deviceId, String deviceName, String deviceType) async {
    try {
      await _devicesRef.child(deviceId).set({
        'name': deviceName,
        'type': deviceType,
        'registered_at': ServerValue.timestamp,
        'last_online': ServerValue.timestamp,
      });
      
      print('Device registered: $deviceId ($deviceName)');
    } catch (e) {
      print('Error registering device: $e');
      rethrow;
    }
  }
  
  // Map a light to a specific hardware pin on a device
  Future<void> mapLightToPin(String deviceId, String lightId, String roomId, int pin) async {
    try {
      // Store mapping on the device
      await _devicesRef.child(deviceId).child('pins').child(lightId).set({
        'pin': pin,
        'type': 'light',
      });
      
      // Store global mapping for app reference
      await _rtdb.ref().child('light_mappings').child(lightId).set({
        'device_id': deviceId,
        'room_id': roomId,
        'pin': pin,
      });
      
      print('Light $lightId mapped to pin $pin on device $deviceId');
    } catch (e) {
      print('Error mapping light to pin: $e');
      rethrow;
    }
  }
  
  // Get all registered devices
  Future<Map<String, dynamic>> getDevices() async {
    try {
      final snapshot = await _devicesRef.get();
      
      if (snapshot.exists && snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      
      return {};
    } catch (e) {
      print('Error getting devices: $e');
      return {};
    }
  }
  
  // Check if a device is online
  Future<bool> isDeviceOnline(String deviceId) async {
    try {
      final snapshot = await _rtdb.ref().child('device_status').child(deviceId).get();
      
      return snapshot.exists && snapshot.value == true;
    } catch (e) {
      print('Error checking device status: $e');
      return false;
    }
  }
  
  // Get a stream of device status updates
  Stream<Map<String, bool>> getDeviceStatusStream() {
    return _rtdb.ref().child('device_status').onValue.map((event) {
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      if (data == null) return {};
      
      final Map<String, bool> deviceStatus = {};
      data.forEach((key, value) {
        if (key is String) {
          deviceStatus[key] = value == true;
        }
      });
      
      return deviceStatus;
    });
  }
}