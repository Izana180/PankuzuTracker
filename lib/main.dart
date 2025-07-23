import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart'; // 用于格式化时间
import 'database_helper.dart';
import 'database_helper.dart';

void main() {
  runApp(
    const MaterialApp(
      home: MyApp(), // 你的页面
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String locationText = '尚未开始获取位置';
  List<String> nearbyDevices = [];
  String motionState = "未知状态";

  @override
  void initState() {
    super.initState();
    _requestPermission();
    // 加速度监听
    accelerometerEvents.listen((AccelerometerEvent event) {
      final double totalAcc = sqrt(
        pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2)
      );

      String state = "未知";
      if (totalAcc < 9.9) {
        state = "静止 🛑";
      } else if (totalAcc < 11.5) {
        state = "步行 🚶‍♂️";
      } else {
        state = "跑步 🏃‍♀️";
      }

      setState(() {
        motionState = state;
      });
    });
  }

  void _showHistory() async {
    final logs = await DatabaseHelper().getLogs();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("历史轨迹记录"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  title: Text("${log['timestamp']}"),
                  subtitle: Text(
                      "位置: ${log['latitude']}, ${log['longitude']}\n状态: ${log['motion_state']}"),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text("关闭"),
              onPressed: () => Navigator.pop(context),
            )
          ],
        );
      },
    );
  }


  Future<void> _requestPermission() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  void _startTracking() async {
  // GPS 监听
  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10,
    ),
  ).listen((Position pos) {
    setState(() {
      locationText = '纬度: ${pos.latitude}, 经度: ${pos.longitude}';
    });
      // ✨ 添加保存数据功能
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    DatabaseHelper().insertLog(
      timestamp: now,
      latitude: pos.latitude,
      longitude: pos.longitude,
      motionState: motionState, // 来自你已有的变量
    );
  });

  // 蓝牙扫描（注意：使用的是静态类方法）
  await FlutterBluePlus.startScan(
    timeout: const Duration(seconds: 5),
  );

  FlutterBluePlus.scanResults.listen((results) {
    List<String> names = [];
    for (var r in results) {
      final name = r.device.platformName.isEmpty ? "Unknown" : r.device.platformName;
      final id = r.device.remoteId.str;
      names.add('$name (ID: $id) (RSSI: ${r.rssi})');
    }
    setState(() {
      nearbyDevices = names;
    });
  });
}


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("パンくずトラッカー v1")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _startTracking,
                child: const Text("开始追踪"),
              ),
              ElevatedButton(
                onPressed: _showHistory,
                child: const Text("查看历史轨迹"),
              ),

              const SizedBox(height: 20),
              Text("当前位置：\n$locationText"),
              const SizedBox(height: 20),
              Text("运动状态：$motionState"),
              const SizedBox(height: 20),
              const Text("附近蓝牙设备："),
              ...nearbyDevices.map((d) => Text(d)).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
