import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int notificationCount = 0;
  bool isBlinking = false;
  Timer? blinkingTimer;
  Color currentBlinkColor = Colors.redAccent.shade700;
  double? efficiencyScore;
  String? efficiencyReport;
  double? efficiencyScore1;
  String? efficiencyReport1;
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> bookedHistory = [];

  // WebSocket connection
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    fetchEfficiencyScore();
    setupWebSocket();
  }

  void setupWebSocket() {
    // WebSocket connection
    final wsUrl = Uri.parse('ws://10.0.2.2:3001');
    // Correct WebSocket URL
    channel = WebSocketChannel.connect(wsUrl);

    channel.stream.listen((message) {
      print('Received: $message');
      // Handle incoming messages here if necessary
    }, onDone: () {
      print('Connection closed');
    }, onError: (error) {
      print('Error: $error');
    });
  }

  Future<void> fetchEfficiencyScore() async {
    final url = Uri.parse("http://10.0.2.2:8080/predict");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "values": [
            200.22,
            31.42,
            97,
            32.85,
            36.81,
            2441,
            65.32,
            118.96,
            21.19,
            43,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        double fetchedScore = data[1]["efficiency_score"] ?? 100;
        String? report = data[1]["analysis_report_user"];

        efficiencyScore1 = data[0]["efficiency_score"] ?? 100;
        efficiencyReport1 = data[0]["analysis_report"];

        setState(() {
          efficiencyScore = fetchedScore;
          efficiencyReport = report;
        });

        if (fetchedScore < 88 && report != null) {
          triggerNotification("Efficiency Alert", report, fetchedScore);
        }
      } else {
        print("⚠️ API Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ ERROR: $e");
    }
  }

  void triggerNotification(String title, String message, double score) {
    setState(() {
      notificationCount++;
      isBlinking = true;
      startBlinkingEffect();

      notifications.add({
        "title": title,
        "date": "${DateTime.now().toLocal()}",
        "message": message,
        "efficiency_score": score,
        "icon": Icons.warning_amber_rounded,
        "color": Colors.redAccent
      });
    });
  }

  void startBlinkingEffect() {
    blinkingTimer?.cancel();
    blinkingTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      setState(() {
        currentBlinkColor = currentBlinkColor == Colors.redAccent.shade700
            ? Colors.red.shade900
            : Colors.redAccent.shade700;
      });
    });
  }

  void stopBlinkingEffect() {
    blinkingTimer?.cancel();
    setState(() {
      isBlinking = false;
      notificationCount = 0;
      currentBlinkColor = Colors.grey.shade500;
    });
  }

  void cancelNotification(int index) {
    setState(() {
      notifications.removeAt(index);
      notificationCount--;

      if (notificationCount == 0) {
        stopBlinkingEffect();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Notification Dismissed"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Updated bookAppointment method to include WebSocket call
  Future<void> bookAppointment(int index) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate == null) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    DateTime finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      bookedHistory.add({
        "title": notifications[index]["title"],
        "message": notifications[index]["message"],
        "dateTime": finalDateTime.toLocal().toString(),
      });

      notifications.removeAt(index);
      notificationCount--;

      if (notificationCount == 0) {
        stopBlinkingEffect();
      }
    });

    // Send data via WebSocket after booking appointment
    sendDataToWebSocket(finalDateTime);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Appointment Booked for ${finalDateTime.toLocal()}"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Function to send data via WebSocket after booking the appointment
  void sendDataToWebSocket(DateTime bookedTime) {
    if (channel != null && channel.sink != null) {
      // Convert data to JSON string before sending

      final String jsonData = jsonEncode({
        "efficiency_score": efficiencyScore1,
        "analyze_issue": efficiencyReport1,
        "booked_time": bookedTime.toIso8601String(),
      });

      // Send JSON string via WebSocket
      channel.sink.add(jsonData);
      print('Sent data: $jsonData');
    } else {
      print('WebSocket channel is not connected.');
    }
  }

  @override
  void dispose() {
    // Close WebSocket connection when the widget is disposed
    channel.sink.close(status.goingAway);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20),
              Text(
                "EV Efficiency Dashboard",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              if (efficiencyScore != null)
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: efficiencyScore! < 88
                              ? [Colors.red.shade700, Colors.red.shade300]
                              : [Colors.green.shade700, Colors.green.shade300],
                        ),
                      ),
                      child: Column(
                        children: [
                          Text("Efficiency Score",
                              style:
                                  TextStyle(fontSize: 20, color: Colors.white)),
                          SizedBox(height: 8),
                          Text(
                            efficiencyScore!.toStringAsFixed(2),
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 20),
              Center(
                child: InkWell(
                  onTap: () {
                    if (notificationCount > 0) {
                      stopBlinkingEffect();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NotificationScreen(
                              notifications,
                              bookAppointment,
                              cancelNotification),
                        ),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: notificationCount > 0
                          ? currentBlinkColor
                          : Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_active, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          notificationCount > 0
                              ? "$notificationCount Unread Notification${notificationCount > 1 ? 's' : ''}"
                              : "No Notifications",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (bookedHistory.isNotEmpty)
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: bookedHistory.map((appointment) {
                      return Card(
                        elevation: 5,
                        child: ListTile(
                          title: Text(appointment["title"]),
                          subtitle: Text(appointment["message"]),
                          trailing: Text(appointment["dateTime"]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationScreen extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final Function(int) bookAppointment;
  final Function(int) cancelNotification;

  NotificationScreen(
      this.notifications, this.bookAppointment, this.cancelNotification,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notifications")),
      body: notifications.isEmpty
          ? Center(
              child: Text("No Notifications",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 5,
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent),
                    title: Text(
                      notifications[index]["title"],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(notifications[index]["message"]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => cancelNotification(index),
                        ),
                        IconButton(
                          icon: Icon(Icons.event_available, color: Colors.blue),
                          onPressed: () => bookAppointment(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
