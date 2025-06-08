import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/servicecontrol/v1.dart' as servicecontrol;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static Future<String?> getAccessToken() async {
    try {
      // Load JSON from secure file in assets
      final String serviceAccountJson =
          await rootBundle.loadString('assets/homi-dc039-c87b9fff9781.json');
      
      // Check if we're using placeholder credentials
      final Map<String, dynamic> credentials = json.decode(serviceAccountJson) as Map<String, dynamic>;
      if (credentials['private_key'] == 'placeholder') {
        print('Using placeholder credentials - notifications will not be sent');
        return null;
      }
      
      List<String> scopes = [
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/firebase.database",
        "https://www.googleapis.com/auth/firebase.messaging"
      ];

      final authCredentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
      final client = await auth.clientViaServiceAccount(authCredentials, scopes);
      final auth.AccessCredentials credentialsData =
          await auth.obtainAccessCredentialsViaServiceAccount(authCredentials, scopes, client);
      
      client.close();
      return credentialsData.accessToken.data;
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  static Future<void> sendNotification(
      String deviceToken, String title, String body, {String? propertyId}) async {
    final String? accessToken = await getAccessToken();
    if (accessToken == null) {
      print('Could not send notification: no valid access token');
      return;
    }
    
    String endpointFCM =
        'https://fcm.googleapis.com/v1/projects/homi-dc039/messages:send';
    
    final Map<String, dynamic> message = {
      "message": {
        "token": deviceToken,
        "notification": {"title": title, "body": body},
        "data": {
          "route": "propertyDetails",
          "propertyId": propertyId ?? "",
        }
      }
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(endpointFCM),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken'
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        print('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Helper method to send notification to current device
  static Future<void> sendNotificationToCurrentDevice(String title, String body, {String? propertyId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceToken = prefs.getString('fcm_token');
      
      if (deviceToken != null) {
        await sendNotification(deviceToken, title, body, propertyId: propertyId);
      } else {
        print('No device token found to send notification');
      }
    } catch (e) {
      print('Error in sendNotificationToCurrentDevice: $e');
    }
  }
}
