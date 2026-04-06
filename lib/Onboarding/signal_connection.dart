import 'package:aminidriver/Container/utils/keys.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signalr_core/signalr_core.dart';

class DriverLocationDto {
  final String driverId;
  final double latitude;
  final double longitude;

  DriverLocationDto({
    required this.driverId,
    required this.latitude,
    required this.longitude,
  });

  factory DriverLocationDto.fromMap(Map<String, dynamic> map) {
    return DriverLocationDto(
      driverId: map['driverId'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }
}

class SignalRService {
  HubConnection? _connection;

  Future<void> init() async {
    try {
      // Wait for the user to be signed in
      final user =
          FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance.authStateChanges().firstWhere(
            (u) => u != null,
          );

      if (user == null) {
        throw Exception("User not logged in");
      }

      // Build SignalR connection with access token factory
      _connection =
          HubConnectionBuilder()
              .withUrl(
                '$baseUrldoc/hubs/location',
                HttpConnectionOptions(
                  accessTokenFactory: () async {
                    try {
                      // Force token refresh if expired
                      final token = await user.getIdToken(true);
                      print(
                        'Firebase token acquired: ${token?.substring(0, 20) ?? "null"}...',
                      ); // log first 20 chars
                      return token;
                    } catch (e) {
                      print('Failed to get Firebase token: $e');
                      return '';
                    }
                  },
                ),
              )
              .withAutomaticReconnect()
              .build();

      // Handle disconnection
      _connection!.onclose((error) {
        print('SignalR disconnected: $error');
      });

      // Optional: reconnect logic
      _connection!.onreconnecting((error) {
        print('SignalR reconnecting: $error');
      });

      _connection!.onreconnected((connectionId) {
        print('SignalR reconnected with connectionId: $connectionId');
      });

      // Start the connection
      await _connection!.start();
      print('SignalR Connected');
    } catch (e) {
      print('Failed to initialize SignalR: $e');
      rethrow; // Optional: propagate to caller
    }
  }

  Future<void> joinRideGroup(String rideId) async {
    await _connection?.invoke('JoinRideGroup', args: [rideId]);
  }

  Future<void> leaveRideGroup(String rideId) async {
    await _connection?.invoke('LeaveRideGroup', args: [rideId]);
  }

  Future<void> updateDriverLocation(
    String rideId,
    double lat,
    double lng,
    String driverId,
  ) async {
    await _connection?.invoke(
      'UpdateDriverLocation',
      args: [rideId, driverId, lat, lng],
    );
  }

  void onDriverLocationUpdate(void Function(DriverLocationDto data) callback) {
    _connection?.on('ReceiveDriverLocation', (dynamic data) {
      if (data == null) return;

      // Convert the dynamic map into a typed DTO
      final location = DriverLocationDto.fromMap(
        Map<String, dynamic>.from(data),
      );
      callback(location);
    });
  }
}
