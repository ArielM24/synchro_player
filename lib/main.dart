import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:synchro_player/data/audio_features.dart';
import 'package:synchro_player/util/audio_processing/audio_classifier.dart';
import 'package:synchro_player/util/audio_processing/audio_reader.dart';
import 'package:synchro_player/util/audio_utils.dart';

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
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Stopwatch stopwatch = Stopwatch();
  late Timer _timer;
  List<String> musicPaths = [
    "/storage/emulated/0/Music/Ellipse.mp3",
    "/storage/emulated/0/Music/Something In The Way (Remastered 2021).mp3",
    "/storage/emulated/0/Music/Last Orders.mp3",
    "/storage/emulated/0/Music/Calcutta.mp3",
    "/storage/emulated/0/Music/Bankrupt!.mp3",
    "/storage/emulated/0/Music/Historical Graffiti.mp3",

    "/storage/emulated/0/Music/Broken.mp3",
    "/storage/emulated/0/Music/My Way.mp3",
    "/storage/emulated/0/Music/The Emptiness Machine.mp3",
    "/storage/emulated/0/Music/In the End.mp3",
    "/storage/emulated/0/Music/Papercut.mp3",
    "/storage/emulated/0/Music/Be Quiet and Drive (Far Away).mp3",
  ];

  List<AudioFeatures> musicFeatures = [];

  List<Map<String, (double, double)>> musicClassification = [];

 _classify() async {
    musicFeatures = [];
    musicClassification = [];
    AudioReader ar = AudioReader();
    for(int i = 0; i < musicPaths.length; i++){
      final features = await ar.readSongFeatures(musicPaths[i]);
      musicFeatures.add(features);
      final classification = AudioClassifier.classifyMultiLabel(features.nomalize());
      musicClassification.add(classification);
    }
  }

  void _printResults() {
    for(int i = 0; i < musicPaths.length; i++){
      debugPrint("${musicPaths[i]}:");
      debugPrint("${musicFeatures[i]}");
      debugPrint("${musicFeatures[i].nomalize()}");
      debugPrint("${musicClassification[i]}");
    }
  }

  void _incrementCounter() async {
    if(Platform.isAndroid){
      final status = await [
        Permission.photos, 
        Permission.videos, 
        Permission.audio
      ].request();  
      debugPrint("$status");
    }
    setState(() {
      stopwatch.reset();
      stopwatch.start();
    });
     _timer = Timer.periodic(Duration(milliseconds: 30), (_) {
      if (stopwatch.isRunning) setState(() {});
    });
    await _classify();
    setState(() {
      stopwatch.stop();
    });
    _printResults();
  }

   @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
          mainAxisAlignment: .center,
          children: [
            const Text('Analysing time:'),
            Text(
              '${stopwatch.elapsed}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
