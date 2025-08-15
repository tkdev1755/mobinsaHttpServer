import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:mobinsa_web/view/displayApplicants.dart';
import 'package:mobinsa_web/model/networkManager.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobinsa_web/uiElements.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/html.dart';
Future<int> tryLoadSession(SessionHandler sessionHandler) async{
  print("LOADING SESSION BACK!");
  if (sessionHandler == null){
    print("Session handler does not exists");
    throw Exception("Session handler does not exists");
  }
  if (await sessionHandler!.hasExistingSession()){
    String token  = (await sessionHandler!.preferences.getString("jwtToken"))!;
    sessionHandler!.login(token);
    sessionHandler!.listenToWSMessages();
    if (await sessionHandler!.successfullyConnected){
      sessionHandler.loggedIn = true;
      return 0;
    }
    sessionHandler.successfullyConnectedCompleter = Completer<bool>();
    return -1;
  }
  sessionHandler.successfullyConnectedCompleter = Completer<bool>();
  return -1;

}
void main()  async {
  SharedPreferencesAsync sharedPreferences = SharedPreferencesAsync();
  SessionHandler? sessionHandler = SessionHandler(sharedPreferences, (Map<String,dynamic> data){}, (Map<String,dynamic> data){});
  await tryLoadSession(sessionHandler);
  runApp(MyApp(preferences: sharedPreferences,sessionHandler: sessionHandler,));
}

class MyApp extends StatefulWidget {
  final SharedPreferencesAsync preferences;
  final SessionHandler sessionHandler;
  const MyApp({super.key, required this.preferences, required this.sessionHandler});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  // @override

  @override
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }
  bool loggedIn = false;
  bool tryLoadedSession = false;

  Widget build(BuildContext context) {
    if (widget.sessionHandler.loggedIn){
      return MaterialApp(
        title: "Bienvenue sur Mob'INSA",
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            textTheme: GoogleFonts.montserratTextTheme()
        ),
        home: DisplayApplicants(sessionHandler: widget.sessionHandler,),
      );
    }
    else{
      return MaterialApp(
        title: "Mob'INSA",
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            textTheme: GoogleFonts.montserratTextTheme()
        ),
        home: MyHomePage(title: "Bienvenue sur Mob'INSA", preferences: widget.preferences,sessionHandler: widget.sessionHandler,),
      );
    }

  }
}

class MyHomePage extends StatefulWidget {
  final SessionHandler sessionHandler;
  MyHomePage({super.key, required this.title, required this.preferences,required this.sessionHandler});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final SharedPreferencesAsync preferences;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  String name = "";
  String mail = "";
  String password = "";
  bool connError = false;
  bool connectToSoftware = false;
  Completer<bool> succesfullyConnected = Completer<bool>();
  bool loggedIn = false;


  @override
  void initState() {
    // TODO: implement initState

    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.primary,

        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title, style: UiText(color: UiColors.white).nText,),
      ),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: FractionalTranslation(
                translation: const Offset(-0.3, 0.3), // -0.1 => décalage à gauche, 0.2 => vers le bas
                child: Opacity(
                  opacity: 0.03,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double width = constraints.maxWidth * 0.25; // 25% de la largeur
                      return Icon(PhosphorIcons.globe(), size: MediaQuery.sizeOf(context).height*1.2,);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(90.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Text("Bienvenue sur Mob'INSA, veuillez vous identifier", style: UiText().vLargeText,),
                  UiShapes.bPadding(20),
                  Text("Nom : ", style: UiText().nText,),
                  UiShapes.bPadding(10),
                  TextField(
                    onChanged: (value){
                      name = value;
                    },
                    decoration: InputDecoration(
                        border: OutlineInputBorder()
                    ),
                  ),
                  UiShapes.bPadding(20),
                  Text("Mot de passe : ", style: UiText().nText,),
                  UiShapes.bPadding(10),
                  TextField(
                    onChanged: (value){
                      password = value;
                    },
                    obscureText: true,
                    decoration: InputDecoration(
                        border: OutlineInputBorder()
                    ),
                  ),
                  UiShapes.bPadding(20),
                  Visibility(child: Text("Erreur lors de la connexion, veuillez réessayer", style: UiText(matColor: Colors.red).nText,) ,visible: connError,),
                  UiShapes.bPadding(20),
                  ElevatedButton(onPressed: () async{
                    if (widget.sessionHandler == null){
                      throw Exception("Session Handler isn't initialized");
                    }
                    else {
                      widget.sessionHandler.setUserData(name, mail, password);
                      widget.sessionHandler.firstHandshake();
                      widget.sessionHandler.listenToWSMessages();
                      connError = !(await widget.sessionHandler!.successfullyConnected);
                      setState(() {

                      });
                      if (!connError){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DisplayApplicants(sessionHandler: widget.sessionHandler,)),);
                      }

                    }
                  }, child: Text("Continuer"))
                ],
              ),
            ),
          ],
        )
      ),
       // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
