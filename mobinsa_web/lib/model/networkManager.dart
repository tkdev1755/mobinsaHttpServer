

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'School.dart';
import 'Student.dart';

class SessionHandler with ChangeNotifier {

  /// OWN WEB CLIENT HEADERs
  static const webClientNewUserHeader = "newUser";
  static const webClientLogIn = "logIn";
  static const webClientVoteUpdate = "voteUpdate";
  static const webClientIdentity = "MobINSAWEBClient";
  /// END OF WEB CLIENT HEADERS
  ///
  /// HTTP SERVER HEADER
  static const String httpConnectedInHeader = "connOk";
  static const String httpConnectError = "connError";
  static const String httpLloginError = "logInError";
  static const String httpLoginOk = "loginOk";
  static const String httpInitDataHeader = "initDataSend";
  static const String httpLoginDataHeader ="loginDataSend";
  static const String httpLoginVoteHeader = "loginVoteData";
  static const String httpStartVoteHeader = "startVote";
  static const String httpStopVoteHeader = "stopVote";
  static const String httpSessionUpdate = "sessionUpdate";
  /// END OF HTTP SERVER HEADER



  SharedPreferencesAsync preferences;
  bool connectToSoftware = false;
  bool loggedIn = false;
  bool voteToGet = false;
  Completer<bool> successfullyConnectedCompleter = Completer<bool>();
  Completer<bool> importedDataCompleter = Completer<bool>();
  Map<String, dynamic> userData = {};
  Future<bool> get successfullyConnected => successfullyConnectedCompleter.future;
  Future<bool> get importedData => importedDataCompleter.future;
  Map<String,dynamic> _sessionData = {};
  Map<String,dynamic> get sessionData => _sessionData;
  bool hasStartedVote = false;
  Map<String, dynamic> voteInfo = {};
  WebSocketChannel?  channel;
  StringBuffer sink = StringBuffer();
  Function(Map<String,dynamic> data) onVoteStart;
  Function(Map<String,dynamic> data) onSessionUpdate;
  Function(Map<String,dynamic> data) onVoteStop;
  SessionHandler(this.preferences, this.onVoteStart, this.onSessionUpdate, this.onVoteStop);
  String lastMessage = "";
  String _jwtToken  = "";
  String getWebSocketUrl() {
    Uri uri = Uri.base;
    if (kDebugMode){
      uri = Uri.parse("http://localhost:8080");
    }
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final host = uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    final url = '$wsScheme://$host$port/ws';
    print("Now connecting to ws channel with the URL  $url");

    return url;
  }
  void startVote(String sender, String rawData){
    voteInfo = jsonDecode(rawData);
    onVoteStart(voteInfo);
    hasStartedVote = true;
    notifyListeners();
  }

  void stopVote(String sender, String rawData){
    voteInfo = jsonDecode(rawData);
    onVoteStop(voteInfo);
    hasStartedVote = false;
    notifyListeners();
  }

  void sendVote(Map<String, dynamic> rawData){
    if (channel == null){
      throw Exception("Not connected to the webSocket");
    }
    rawData["token"] = _jwtToken;
    String data = jsonEncode(rawData);
    channel!.sink.add("$webClientVoteUpdate;$webClientIdentity;$data");
  }

  static Map<String, Map<int,dynamic>> deserializeData(Map<String,dynamic> data){

    Map<int,Student> students = {};
    Map<int,School> schools = {};
    // je m'assure de l'existence des clés que je recherche pour désérialiser mes données
    if ((!data.containsKey("schools")) || (!data.containsKey("students"))){
      throw Exception("404 - File doesn't have the required fields to reconstruct the data");
    }
    if (!data.containsKey("version")){
      print("Save from 1.0.0, loading it as it causes no crashes");
    }
    List<dynamic> jsonSchools = data["schools"];
    List<dynamic> jsonStudents = data["students"];
    // Je désérialise chaque école
    for (var entry in jsonSchools){
      schools[entry[School.jsonId]] = School.fromJson(entry);
    }
    // Je réajuste l'ID global des écoles en cas d'ajout d'une nouvelle école
    School.setGlobalID(schools.length);
    int i = 0;
    // Je refait la même chose pour les étudiants
    for (var entry in jsonStudents){
      students[entry[School.jsonId]] = Student.fromJson(entry, schools.values.toList());
      i++;
    }
    /*print("Currently ${students.where((e) => e.accepted != null).length} Students has an acceptedChoice");
    print("Currently There is ${schools.length} schools - exact data is \n ${schools}");*/

    // Je retourne ensuite les données désérialisées
    return {
      "schools" : schools,
      "students" : students,
    };
  }

  void saveSession(sender, rawData, WebSocketSink webSocket){
    Map<String,dynamic> requestData = jsonDecode(rawData);
    if (!requestData.containsKey("token")) {
      print("save Session - Token Header missing");
      throw Exception("Bad header");
    }
    String token = requestData["token"];
    _jwtToken = token;
    preferences.setString("jwtToken", token);
    preferences.setString("expiry", DateFormat("dd-MM-yyy/HH-mm").format(DateTime.now().add(Duration(hours: 2))));
    preferences.setString("name", userData["name"]);
    preferences.setString("mail", userData["mail"]);
  }

  void restoreSession() async{
    _jwtToken = (await preferences.getString("jwtToken"))!;
    userData["name"] = await preferences.getString("name");
    userData["mail"] = await preferences.getString("mail");
  }

  Future<bool> hasExistingSession() async{
    return (await preferences.containsKey("name") && await preferences.containsKey("jwtToken") && await preferences.containsKey("mail"));
  }

  Map<String,dynamic> importData(String sender, String rawData) {
    Map<String,dynamic> jsonData = jsonDecode(rawData);
    return jsonData;
  }


  void processMessages(dynamic data, WebSocketSink webSocket){
    List<String> decodedMessage = [];
    if (lastMessage == data){
      print("[NETWORK] - processMessages : Same message than last one, aborting.");
      return;
    }
    if (false /*data.length > 2048 || sink.isNotEmpty*/){
      print("[NETWORK] - processMPMessages : Large data waiting for all the packets... ${data.length}");
      sink.write(data);
      if (sink.toString().contains("\n")){
        print("[NETWORK] - processMPMessages : Last Character from data packet, now unpacking adding ${data.length}");
        print("[NETWORK] - processMPMessages : Sink ressembles to this, trying to decode it ${sink.length}");
        decodedMessage = sink.toString().split(";");
        sink.clear();
      }
      else{
        print("[NETWORK] - processMPMessages : Still recieving packets");
        return;
      }
    } else{
       decodedMessage = data.split(";");
    }
    lastMessage = data;
    print("[NETWORK] - Processing message");
    if (decodedMessage.length < 3) {
      print("ProcessMessage - Unrecognized format");
      throw Exception("Unrecognized format");
    }
    String primitive = decodedMessage[0];
    String sender = decodedMessage[1];
    String rawData = decodedMessage[2];
    print("[NETWORK] - Primitive from message is ${primitive}");
    switch (primitive){
      case httpConnectedInHeader:
        print("[NETWORK] - Message type : Connection successful");
        saveSession(sender,rawData, webSocket);
        successfullyConnectedCompleter.complete(true);
        break;
      case httpConnectError:
        print("[NETWORK] - Message type : Connection error");
        successfullyConnectedCompleter.complete(false);
        break;
      case httpLoginOk:
        print("[NETWORK] - Message type : Logged In");
        if (!successfullyConnectedCompleter.isCompleted){
          restoreSession();
          successfullyConnectedCompleter.complete(true);
        }
        break;
      case httpLloginError:
        print("[NETWORK] - Message type :  Error while trying to log In");
        successfullyConnectedCompleter.complete(false);
        break;
      case httpInitDataHeader:
        print("[NETWORK] - Message type : Finished importing raw data");
        _sessionData = importData(sender, rawData);
        importedDataCompleter.complete(true);
        break;
      case httpLoginDataHeader:
        print("[NETWORK] - Message type : Got data after being logged In");
        _sessionData = importData(sender, rawData);
        importedDataCompleter.complete(true);
        break;
      case httpLoginVoteHeader:
        print("[NETWORK] - Message type : There was an ongoing vote");
        voteInfo = jsonDecode(rawData);
        voteToGet = true;
        hasStartedVote = true;
        break;
      case httpStartVoteHeader:
        print("[NETWORK] - Message type : Vote started for said student");
        startVote(sender, rawData);
        break;
      case httpStopVoteHeader:
        print("[NETWORK] - Message type : Vote started for said student");
        stopVote(sender, rawData);
        break;
      case httpSessionUpdate:
        print("[NETWORK] - Message type : Session update");
        Map<String,dynamic> data = jsonDecode(rawData);
        onSessionUpdate(data);
        break;
      default :
        print("ProcessMessages - UnrecognizedMessage header");
        throw Exception("Unrecognized message header");
    }
  }
  void connectToWebSocket(){
    String wsAdress = getWebSocketUrl();
    channel = WebSocketChannel.connect(Uri.parse(wsAdress));
  }

  void firstHandshake(){
    connectToWebSocket();
    if (channel == null){
      print("firstHandshake - The channel isn't initialized properly");
      throw Exception("The channel isn't initialized properly");
    }
    print("[NETWORK] - Sending data to connect to Mob'INSA software ");
    channel!.sink.add('newUser;null;{"name": "${userData["name"]}", "mail" : "${userData["mail"]}", "password" :"${userData["password"]}", "ip" : "XXX.XXX.XXX.XXX"}');
    print("[NETWORK] - Sent data");
    connectToSoftware = false;
  }

  void login(String token){
    connectToWebSocket();
    if (channel == null){
      print("login - The channel isn't initialized properly");
      throw Exception("The channel isn't initialized properly");
    }
    channel!.sink.add('$webClientLogIn;$token;{"token" : "$token"}');
  }


  void listenToWSMessages(){
    if (channel == null){
      print("Tried to listen to messages while WebSocket channel uninitialized");
      throw Exception("The Websocket is null");
    }
    channel?.stream.listen((data){
        print("[NETWORK] - New Message from WS");
        processMessages(data, channel!.sink);
    });
    /*channel.onOpen.listen((event){
      if (connectToSoftware){
        channel.send('newUser;null;{"name": "${name}", "mail" : "${mail}", "password" :"${password}", "ip" : "XXX.XXX.XXX.XXX"}');
      }
      else processMessages(event);
      print("Web socket connected");

    })*/;
  }

  void setConnectToSoftware(bool value){
    connectToSoftware = value;
  }

  void setUserData(String name, String email, String password){
    userData["name"] = name;
    userData["mail"] = email;
    userData["password"] = password;
  }
}