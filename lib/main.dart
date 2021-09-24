import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:nordic_dfu/nordic_dfu.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:percent_indicator/percent_indicator.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult>? scanSubscription;
  List<ScanResult> scanResults = <ScanResult>[];
  bool dfuRunning = false;
  int? dfuRunningInx;
  late StateSetter _setModalState;
  double progress = 0.0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> doDfu(String deviceId) async {
    stopScan();
    dfuRunning = true;
    try {
      var s = await NordicDfu.startDfu(
        deviceId,
        'assets/file.zip',
        fileInAsset: true,
        progressListener:
            DefaultDfuProgressListenerAdapter(onProgressChangedHandle: (
          deviceAddress,
          percent,
          speed,
          avgSpeed,
          currentPart,
          partsTotal,
        ) {
          print(
              'deviceAddress: $deviceAddress, percent: $percent, currentPart: $currentPart, total: $partsTotal');

          _setModalState(() {
            var progressDecimal = (percent! / 100);
            if (progressDecimal <= 1) {
              progress = progressDecimal;
            } else if (progressDecimal == 1) {
              print('Transfer is complete');
              Navigator.pop(context);
            }
          });
        }),
      );

      dfuRunning = false;
    } catch (e) {
      dfuRunning = false;
      print(e.toString());
    }
  }

  void startScan() {
    scanSubscription?.cancel();
    setState(() {
      scanResults.clear();
      scanSubscription = flutterBlue.scan().listen(
        (scanResult) {
          if (scanResults.firstWhereOrNull(
                  (ele) => ele.device.id == scanResult.device.id) !=
              null) {
            return;
          }
          setState(() {
            /// add result to results if not added
            scanResults.add(scanResult);
          });
        },
      );
    });
  }

  void stopScan() {
    flutterBlue.stopScan();
    scanSubscription?.cancel();
    scanSubscription = null;
    setState(() => scanSubscription = null);
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = scanSubscription != null;
    final hasDevice = scanResults.isNotEmpty;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
          actions: <Widget>[
            isScanning
                ? IconButton(
                    icon: Icon(Icons.pause_circle_filled),
                    onPressed: dfuRunning ? null : stopScan,
                  )
                : IconButton(
                    icon: Icon(Icons.play_arrow),
                    onPressed: dfuRunning ? null : startScan,
                  )
          ],
        ),
        body: !hasDevice
            ? const Center(
                child: Text('No device'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemBuilder: _deviceItemBuilder,
                separatorBuilder: (context, index) => const SizedBox(height: 5),
                itemCount: scanResults.length,
              ),
      ),
    );
  }

  Widget _deviceItemBuilder(BuildContext context, int index) {
    var result = scanResults[index];

    return DeviceItem(
      isRunningItem: (dfuRunningInx == null ? false : dfuRunningInx == index),
      scanResult: result,
      onPress: dfuRunning
          ? () async {
              await NordicDfu.abortDfu();
              setState(() {
                dfuRunningInx = null;
              });
            }
          : () async {
              showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(builder:
                      (BuildContext context, StateSetter setModalState) {
                    _setModalState = setModalState;
                    return Dialog(
                      backgroundColor: Colors.white,
                      child: Container(
                        // use container to change width and height
                        height: 190,
                        width: 500,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text('Updating device firmware',
                                  style: TextStyle(
                                      color: Color(0xFF222222),
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(
                                height: 20.0,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "30MB/240MB",
                                      style: TextStyle(
                                        fontSize: 14.0,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                        (progress * 100).round().toString() +
                                            '%'),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10.0,
                              ),
                              LinearPercentIndicator(
                                lineHeight: 16.0,
                                animateFromLastPercent: true,
                                percent: progress,
                                backgroundColor: Color(0xFFEFEFEF),
                                progressColor: Color(0xFF3CB232),
                              ),
                              const SizedBox(
                                height: 10.0,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    SizedBox(
                                      width: 125,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          _setModalState(() {
                                            if (progress <= 1 &&
                                                (progress + 0.1) < 1) {
                                              progress = progress + 0.1;
                                              print('added 10 percent');
                                            } else {
                                              print('Transfer is complete');
                                              progress = 0.0;
                                              Navigator.pop(context);
                                            }
                                          });
                                        },
                                        child: const Text(
                                          'CANCEL',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              side: const BorderSide(
                                                color: Color(0xFF2222224B),
                                              )),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 10.0,
                                    ),
                                    SizedBox(
                                      width: 125,
                                      child: FlatButton(
                                          color: Color(0xFF204D7A),
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text(
                                            'OK',
                                            style:
                                                TextStyle(color: Colors.white),
                                          )),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  });
                },
              );
              setState(() {
                dfuRunningInx = index;
              });
              await doDfu(result.device.id.id);
              setState(() {
                dfuRunningInx = null;
              });
            },
    );
  }
}

class ProgressListenerListener extends DfuProgressListenerAdapter {
  @override
  void onProgressChanged(String? deviceAddress, int? percent, double? speed,
      double? avgSpeed, int? currentPart, int? partsTotal) {
    super.onProgressChanged(
        deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal);
    print('deviceAddress: $deviceAddress, percent: $percent');
  }
}

class DeviceItem extends StatelessWidget {
  final ScanResult scanResult;

  final VoidCallback? onPress;

  final bool? isRunningItem;

  DeviceItem({required this.scanResult, this.onPress, this.isRunningItem});

  @override
  Widget build(BuildContext context) {
    var name = 'Unknown';
    if (scanResult.device.name.isNotEmpty) {
      name = scanResult.device.name;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: <Widget>[
            Icon(Icons.bluetooth),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name),
                  Text(scanResult.device.id.id),
                  Text('RSSI: ${scanResult.rssi}'),
                ],
              ),
            ),
            TextButton(
                onPressed: onPress,
                child: isRunningItem! ? Text('Abort Dfu') : Text('Start Dfu'))
          ],
        ),
      ),
    );
  }
}
