// lib/services/iot_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:illumi_home/models/room.dart';

/// A service dedicated to IoT communication via Firebase Realtime Database
/// This service handles NodeMCU/Arduino Uno integration for controlling lights
class IoTService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  
  // Add a dedicated node for IoT device statuses
  final DatabaseReference _deviceStatusRef;
  final DatabaseReference _commandsRef;
  
  // Constructor
  IoTService()
      : _deviceStatusRef = FirebaseDatabase.instance.ref().child('device_status'),
        _commandsRef = FirebaseDatabase.instance.ref().child('commands');
  
  // Listen for device connection status changes
  Stream<Map<String, bool>> getDeviceStatusStream() {
    return _deviceStatusRef.onValue.map((event) {
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      if (data == null) return {};
      
      // Convert to a map of device IDs to connection status
      Map<String, bool> deviceStatus = {};
      data.forEach((key, value) {
        if (key is String) {
          deviceStatus[key] = value == true;
        }
      });
      
      return deviceStatus;
    });
  }
  
  // Send a direct command to a specific device
  Future<void> sendCommand(String deviceId, String command, Map<String, dynamic> params) async {
    try {
      // Create a command entry with timestamp for the device to pick up
      await _commandsRef.child(deviceId).set({
        'command': command,
        'params': params,
        'timestamp': ServerValue.timestamp,
        'processed': false,
      });
      
      print('Command sent to device $deviceId: $command with params $params');
    } catch (e) {
      print('Error sending command to device: $e');
      rethrow;
    }
  }
  
  // Send light control command to a specific device
  Future<void> controlLight(String deviceId, String lightId, bool turnOn) async {
    await sendCommand(deviceId, 'toggle_light', {
      'light_id': lightId,
      'state': turnOn ? 1 : 0,
    });
  }
  
  // Send brightness control command
  Future<void> setBrightness(String deviceId, String lightId, int brightness) async {
    // Make sure brightness is within valid range (0-100)
    final validBrightness = brightness.clamp(0, 100);
    
    await sendCommand(deviceId, 'set_brightness', {
      'light_id': lightId,
      'brightness': validBrightness,
    });
  }
  
  // Register a new device
  Future<void> registerDevice(String deviceId, String deviceName, String deviceType) async {
    try {
      await _rtdb.ref().child('devices').child(deviceId).set({
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
  
  // Map a light to a specific hardware pin on the device
  Future<void> mapLightToPin(String deviceId, String lightId, int pin) async {
    try {
      await _rtdb.ref().child('devices').child(deviceId).child('pins').child(lightId).set({
        'pin': pin,
        'type': 'light',
      });
      
      // Store this mapping for future reference
      await _rtdb.ref().child('light_mappings').child(lightId).set({
        'device_id': deviceId,
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
      final snapshot = await _rtdb.ref().child('devices').get();
      
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
      final snapshot = await _deviceStatusRef.child(deviceId).get();
      
      if (snapshot.exists && snapshot.value != null) {
        return snapshot.value == true;
      }
      
      return false;
    } catch (e) {
      print('Error checking device status: $e');
      return false;
    }
  }
  
  // Get status updates from a specific device
  Stream<Map<String, dynamic>> getDeviceUpdates(String deviceId) {
    return _rtdb.ref().child('device_updates').child(deviceId).onValue.map((event) {
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      if (data == null) return {};
      
      return Map<String, dynamic>.from(data);
    });
  }
}