import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

const String server = "broker.hivemq.com";
const String clientIdentifier = "my_identifier";
const int port = 1883;

const kPingHost = '8.8.4.4';
const kPingPort = 53;
const kPingTimeoutDuration = Duration(seconds: 3);
const kLookupInterval = Duration(seconds: 5);

const networkServer = "";

final _connectivityInstance = Connectivity();

class MQTTClientConnector {
  final MqttServerClient _client = MqttServerClient.withPort(
    server,
    clientIdentifier,
    port,
    maxConnectionAttempts: 10,
  );
  MqttConnectionState get state =>
      _client.connectionStatus?.state ?? MqttConnectionState.disconnected;
  Future<void> connect({
    required String clientId,
  }) async {
    _client.port = port;
    _client.logging(on: false);
    _client.setProtocolV311();
    _client.keepAlivePeriod = 1200;
    _client.onDisconnected = () {
      print('MQTT is disconnected');
    };
    _client.secure = false; // true for secure connection
    _client.autoReconnect = true; // true to automatically reconnect

    _client.resubscribeOnAutoReconnect = true;
    _client.disconnectOnNoResponsePeriod = 5;

    final connMessage = MqttConnectMessage()..withClientIdentifier(clientId);

    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
      debugPrint(
        'Connecting with Client_id :: ${_client.clientIdentifier} to Server :: ${server}  Mqtt Client',
      );
    } on ConnectionException catch (e) {
      debugPrint('Exception thrown while trying to connect to the broker: $e');
    } on SocketException catch (e) {
      debugPrint('Exception thrown while trying to connect to the broker: $e');
    } catch (e) {
      debugPrint('MQTT Server::exception - $e');
      _client.disconnect();
    }
  }

  int? publish() {
    final pubMessage =
        MqttClientPayloadBuilder().addUTF8String('message').payload;

    return _client.publishMessage(
      'topic',
      MqttQos.atLeastOnce,
      pubMessage!,
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final connectionResult = ValueNotifier(ConnectivityResult.none);
  final mqttConnectionStatus = ValueNotifier(MqttConnectionState.disconnected);
  final internetConnection = ValueNotifier(false);

  final connector = MQTTClientConnector();
  final pubId = ValueNotifier<int?>(null);
  final lastPubStatusSuccess = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () async {
      await connector.connect(clientId: clientIdentifier);
      Timer.periodic(const Duration(seconds: 2), (timer) async {
        mqttConnectionStatus.value = connector.state;
      });
    });
    _connectivityInstance.onConnectivityChanged.listen((event) {
      connectionResult.value = event;
    });
    Timer.periodic(kLookupInterval, (timer) async {
      Socket? sock;
      try {
        sock = await Socket.connect(kPingHost, kPingPort,
            timeout: kPingTimeoutDuration)
          ..destroy();

        internetConnection.value = true;
      } on SocketException catch (_) {
        sock?.destroy();
        internetConnection.value = false;
      } catch (e) {
        sock?.destroy();
        internetConnection.value = false;
      }
    });
  }

  void _publishMessage() {
    try {
      pubId.value = connector.publish();
      lastPubStatusSuccess.value = true;
    } catch (e) {
      lastPubStatusSuccess.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: [
                const Text('Connectivity Result'),
                const SizedBox(width: 80),
                ValueListenableBuilder(
                  valueListenable: connectionResult,
                  builder: (_, result, __) {
                    return Text(result.name);
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Mqtt Connected'),
                const SizedBox(width: 80),
                ValueListenableBuilder(
                  valueListenable: mqttConnectionStatus,
                  builder: (_, result, __) {
                    return Text(result.name);
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Internet available'),
                const SizedBox(width: 80),
                ValueListenableBuilder(
                  valueListenable: internetConnection,
                  builder: (_, result, __) {
                    return Text(result.toString());
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Publish id'),
                const SizedBox(width: 80),
                ValueListenableBuilder(
                  valueListenable: pubId,
                  builder: (_, result, __) {
                    return Text(result.toString());
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Last Published Success'),
                const SizedBox(width: 80),
                ValueListenableBuilder(
                  valueListenable: lastPubStatusSuccess,
                  builder: (_, result, __) {
                    return Text(result.toString());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _publishMessage,
        tooltip: 'Publish',
        child: const Icon(Icons.add),
      ),
    );
  }
}
