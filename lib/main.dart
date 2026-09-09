import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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
    String song1 = "/storage/emulated/0/Music/Called Out In The Dark.mp3";
    String song2 = "/storage/emulated/0/Music/Cherry Waves.mp3";
    String song3 = "/storage/emulated/0/Music/Dive.mp3";
    String song4 = "/storage/emulated/0/Music/Ellipse.mp3";
    String song5 = "/storage/emulated/0/Music/Something In The Way (Remastered 2021).mp3";
    String song6 = "/storage/emulated/0/Music/Something About Us.mp3";
    final r1 = await classifySong(song1);
    final r2 = await classifySong(song2);
    final r3 = await classifySong(song3);
    final r4 = await classifySong(song4);
    final r5 = await classifySong(song5);
    final r6 = await classifySong(song6);
    debugPrint("$r1 $r2 $r3 $r4 $r5 $r6");
    setState(() {
      stopwatch.stop();
    });
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
