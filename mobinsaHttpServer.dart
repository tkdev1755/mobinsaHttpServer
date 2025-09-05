import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' hide ECPrivateKey, ECPublicKey, RSAPrivateKey;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:uuid/uuid.dart';
import 'KeychainAPI/keyring.dart';
import 'certificateGenerator.dart';
import 'package:path/path.dart' as path;
/// Keyring to store secrets in a secure manner
final Keyring keyring = Keyring();
/// Name of the app in the keychain of the OS
const String httpServiceName = "mobinsaHTTPServer";
/// Username used in the keychain of the OS
const String httpUsername = "mobInsaJwtKey";
/// IP used to communicate with the Master Program (e.g mobinsa.exe, mobinsa.app or mobinsa)
final masterProgamIP = InternetAddress.loopbackIPv4;
/// Port used to communicate with the Master Program (e.g mobinsa.exe, mobinsa.app or mobinsa)
final masterProgramPORT = 7070;
/// IP used to Serve the MobINSA web app
final httpIP = InternetAddress.anyIPv4;
/// Port used to Serve the MobINSA web app
final httpPORT = 8080;

/// Messages between the Master Program and Web Clients follow this structure
/// ACTION;SENDER;DATA
/// Where ACTION is one of the headers that are defined below, and sender is the xIdentity
/// And DATA depends on what action was specified before

/// OWN HTTP SERVER HEADERS

// Headers that are used to communicate with the Master Program

/// Name of the server that is used in the communications with the master program (MP)
/// Used in the SENDER field of any messgae going to the Master program (MP)
const httpServerIdentity = "mHTTPServerV1.0.0";

/// Header used to indicate that the HTTP server has been correctly started up
const httpInitHeader = "httpInit";
/// Data that is sent with the httpInitHeader
String httpInitRawData = '{"name" :"MobINSAHTTPServer - v1.0.0", "ipaddr" : "${httpIP.address}", "hostaddr" : "${httpIP
    .host}"}';
/// Header used to indicate that the session Data (session password and other info) was well received
const String sessionDataReceivedHeader = "fSessionData";
/// Header used to notify the MP of a new user which was successfully connected
const String newUserHeader = "newUser";
/// Header used to ask the MP for jury data when a user logged back in
const String loginDataHeader = "loginGetData";
/// Header used to notify the MP that the initial data (jury data) was well received
const String initDataSentHeader = "fInitData";
/// Header used to notify the MP that the vote start notification was broadcasted to all connected clients
const String voteOkHeader = "voteOk";
/// Header used to notify the MP that the vote end notification was broadcasted to all connected clients
const String voteEndHeader = "voteEndOk";
/// Header used to notify the MP that there was a vote update from one of the connected client (voted for one choice, canceled current vote)
const String voteUpdateHeader = "voteUpdate";

// Headers that are used for communicating with WS
/// Header used to notify the client that the authentification was successful
const String connectedInHeader = "connOk";
/// Header used to notify the client that the authentification wasn't successful
const String connectErrorHeader = "connError";
/// Header used to notify the client that the login wasn't successful
const String loginErrorHeader = "logInError";
/// Header used to notify the client that he is logged in
const String loginOkHeader = "loginOk";
/// Header used to send the initial data (jury data) to the clients
const String initDataHeader = "initDataSend";

/// Header used to send the  jury data to a client which logged back in
const String wsLoginDataHeader = "loginDataSend";
/// Header used to send the  vote data to a client which logged back in, if there is a vote currently going on
const String wsLoginVoteHeader = "loginVoteData";
/// Header used to notify the clients that a vote started
const String startVoteHeader = "startVote";
/// Header used to notify the clients that the ongoing vote was stopped
const String stopVoteHeader = "stopVote";
/// Header used to send the updates from the MP to the connected clients (choice acceptance, choice refusal, canceled action etc...)
const String sessionUpdateHeader = "sessionUpdate";
/// END OF HTTP SERVER HEADERS

///  MASTER PROGRAM HEADERS
///  mp stands for Master Program
///  The Description for these headers can be found in the MobINSA repo, at /github.com/tkdev1755/mobinsa/blob/mobinsa_collaborative/lib/model/networkManager.dart
const mpSessionDataHeader = "sessionDataExchange";
const mpInitDataHeader = "initData";
const mpStartVoteHeader = "startVote";
const mpStopVoteHeader = "closeVote";
const mpLoginDataHeader = "loginData";
const mpSessionUpdate = "sessionUpdate";
/// END OF MASTER PROGRAM HEADERS

/// WS SPECIFIC HEADERS
///
/// The Description for these headers can be found in this repo in the following file mobinsa_web/lib/model/networkManager.dart
const webClientNewUserHeader = "newUser";
const webClientLogIn = "logIn";
const webClientVoteUpdate = "voteUpdate";
const webClientIdentity = "MobINSAWEBClient";
final wsHeaders = [webClientNewUserHeader,webClientLogIn];
/// END OF WS SPECIFIC HEADERS

/// Map which contains all the successfully connected clients (Websockets for which the authenticate() function returned true
///
/// Has a Websocket as a key and Map as value (containing the jwt token and other useful info about the client)
final Map<WebSocket, Map<String,dynamic>> clients = {};
/// List containing clients which logged back in and are waiting for session data
List<WebSocket> waitingClientsForData = [];

/// Socket used to communicate with the master program
late Socket socket;

/// Describe whether the jury has been started by the user of the MP or not
bool startedJury = false;

/// Stores the current vote data, to send it to users that try to log back in
String? currentVote;

/// Stores what currentVote contains but in a Map
Map<String,dynamic>? currentVoteInfo;

/// Completer used to track if the session data was well received
Completer<bool> receivedSessionData = Completer<bool>();

/// String containing the session password sent by the MP
String sessionPassword = "";

/// DEPRECATED - List containing the trusted emails by the user of the MP
///
/// Was initially here to get a better security, by getting only trusted emails access the web app, through CAS Auth
List<String> trustedEmails = [];

/// Buffer used when large messages are sent through the MP Socket
StringBuffer sink = StringBuffer();

/// Function which gets the JWT key from the OS keychain. If non-existant, creates it and stores it in the keychain
///
/// Returns a String with the JWT key used to authenticate users
String getJWTKey(){
  String? registeredPassword = keyring.getPassword(httpServiceName, httpUsername);
  if (registeredPassword == null){
    print("JWT key doesn't exists in system, creating it");
    final String jwtKey = Uuid().v6();
    int result = keyring.setPassword(httpServiceName, httpUsername, jwtKey);
    if (result == -1){
      throw Exception("Error while setting the password");
    }
    registeredPassword = jwtKey;
  }
  return registeredPassword;
}

/// Function which creates the JWT if a user has been correctly logged in
///
/// Returns the JWT and the created token
(JWT,String) createJWT(){
  Uuid uuidMachine = Uuid();
  final JWT jwt = JWT(
    // Payload
    {
      'id': uuidMachine.v6(),
      'server': {
        'id': '3e4fc296',
        'loc': 'euw-2',
      }
    },
    issuer: 'http://tkdev1755.github.io/mobinsa/',
  );
  String token = jwt.sign(SecretKey(getJWTKey()), expiresIn: Duration(hours: 2));
  return (jwt,token);
}

/// Function which is called when webClientNewUserHeader header is received from a WebSocket (web client)
void addUser(String sender, String rawData, Socket masterSocket,  WebSocket clientSocket){
  if (!clients.containsKey(clientSocket) || clients.values.where((e) => e["uid"] != null && e["uid"] == sender).isEmpty){
    // print("User should have these emails ${trustedEmails} and this password ${sessionPassword}");
    Map<String,dynamic> requestData = jsonDecode(rawData);
    if (!requestData.containsKey("password") || !requestData.containsKey("name") || !requestData.containsKey("mail")) throw Exception("Bad header");
    if (authenticate(requestData["mail"], requestData["password"])){
      print("addUser - User authenticated and added");
      (JWT, String) jwt = createJWT();
      socket.write('newUser;${httpServerIdentity};{"name" : "${requestData["name"]}", "mail" : "${requestData["mail"]}", "uid" : "${jwt.$1.jwtId}"}');
      clients[clientSocket] = {
        "uid" : jwt.$1.jwtId,
        "jwt" : jwt,
        "token" : jwt.$2,
        "name" : requestData["name"],
        "mail" : requestData["mail"]
      };
      clientSocket.add('$connectedInHeader;$httpServerIdentity;{"token" : "${jwt.$2}", "uid" : "${jwt.$1.jwtId}"}');
    }

    else{
      print("addUser - User hasn't the right credentials ");
      print("addUser - User has the following credentials ${requestData["mail"]} -${requestData["password"]}");
      clientSocket.add('$connectErrorHeader;$httpServerIdentity;null');
    }
  }
}

/// Function which tests if the password is correct or not
/// NEEDS better implementation
bool authenticate(email, password){
  return sessionPassword == password /*&& trustedEmails.contains(email)*/;
}
/// Function which checks if a JWT is still valid from
///
/// Returns 0 if the JWT is still valid
/// Returns -1 if the JWT isn't recognized at all
/// Returns -2 if the JWT expired
int checkJWT(token){
  try
  {
    final jwt = JWT.verify(token, SecretKey(getJWTKey()));
    print("Jwt got decoded");
    if (clients.values.where((e) => e["token"] == token).isEmpty){
      return -1;
    }
    return 0;
  }
  on JWTExpiredException {
    print("JWT Expired");
    return -2;
  }
  on JWTException catch (e){
    print("JWT wasn't decoded ${token}");
    print(e.message);
    return -1;
  }
}
/// Functions which is called when webClientLogIn header is received, checks if the JWT is still valid and updates the associated webSocket if true
///
/// Takes a String which represents the SENDER field of a network request, a String which represents the DATA field of a network request (in a UTF-8 Format)
/// , a Socket to send the messages back to the MP and a WebSocket to communicate with the concerned webSocket
void logUserIn(String sender, String rawData, Socket masterSocket, WebSocket webSocket){
  Map<String,dynamic> requestData = jsonDecode(rawData);
  if (!requestData.containsKey("token")) throw Exception("Missing keys in rawData");
  int tokenStatus = checkJWT(requestData["token"]);
  switch (tokenStatus){
    case 0:
      webSocket.add("$loginOkHeader;${httpServerIdentity};null");
      WebSocket? oldWebSocket = clients.entries.where((e) => e.value.containsKey(["id"]) && e.value["token"] == requestData["token"]).firstOrNull?.key;
      if (oldWebSocket != null){
        clients[webSocket] = clients[oldWebSocket]!;
        clients.remove(oldWebSocket);
      }
      print("[NETWORK] - User JWT is valid");
      webSocket.add("$loginOkHeader;$httpServerIdentity;null");
      if (startedJury){
        waitingClientsForData.add(webSocket);
        masterSocket.write("$loginDataHeader;${httpServerIdentity};null");
      }
      break;
    case -1:
      print("[NETWORK] - Token doesn't exists");
      webSocket.add('$loginErrorHeader;$httpServerIdentity;{"reason" : "nullToken"}');
      break;
    case -2:
      print("[NETWORK] - Token is too old");
      webSocket.add('$loginErrorHeader;$httpServerIdentity;{"reason" : "oldToken"}');
      break;
  }

}

/// Functions which is called each times a messages from a WebSocket is received, decodes the header and calls the appropriate method
///
/// Takes the raw data (UTF-8) from the websocket, the WebSocket which sent the message and a Socket which represents the MP Socket (Master Program Socket)
void processWebSocketMessage(dynamic data, WebSocket webSocket, Socket masterSocket){
  List<String> decodedMessage = data.split(";");
  if (decodedMessage.length < 3) throw Exception("Unrecognized format");
  String primitive = decodedMessage[0];
  String sender = decodedMessage[1];
  String rawData = decodedMessage[2];
  switch (primitive){
    case webClientNewUserHeader:
      print("[NETWORK] - Message type : New user from WS");
      addUser(sender, rawData, masterSocket, webSocket);
      break;
    case webClientLogIn:
      print("[NETWORK] - Message type : User logging in back");
      logUserIn(sender, rawData, masterSocket, webSocket);
      break;
    case webClientVoteUpdate:
      sendVoteUpdate(sender, rawData, masterSocket);
      print("[NETWORK] - Message type : User Voting, transmitting the message");
    default:
      throw Exception("Unknown header from websocket");
  }
}

/// Function which is Called when the mpSessionDataHeader Header is received, and adds the session data to the sessionPassword and trustedEmails
///
/// Takes a String which represent the SENDER field of a network message and the DATA field
void addSessionData(String sender, String rawData){
  Map<String,dynamic> requestData = jsonDecode(rawData);
  if (!requestData.containsKey("sessionPassword") || !requestData.containsKey("trustedEmails")) throw Exception("Bad header");
  sessionPassword = requestData["sessionPassword"];
  print(requestData["trustedEmails"].first.runtimeType);
  for (var email in requestData["trustedEmails"]){
    trustedEmails.add(email);
  }
  receivedSessionData.complete(true);
}

/// Function which is called when the mpInitDataHeader is received and send the init data (jury data) to all the connected web clients
/// Sends a confirmation message afterwards to the MP
///
/// Takes a String which represents the SENDER field of a network message and a String which represents the DATA field of a network message
/// Takes the Socket which represents the MP socket to send the confirmation message
void sendInitialData(String sender, String rawData, Socket masterSocket){
  for (var client in clients.keys){
    client.add("$initDataHeader;$httpServerIdentity;$rawData");
  }
  masterSocket.write('${initDataSentHeader};${httpServerIdentity};{numberOfClients : ${clients.length}');
  startedJury = true;
}

/// Function which is called when the mpLoginDataHeader is received and send the jury data to logged back in users
///
/// Takes a String which represents the SENDER field of a network message and a String which represents the DATA field of a network message
/// Takes the Socket which represents the MP socket to send the confirmation message
void sendDataToLoggedInUser(String sender, String rawData, Socket masterSocket){
  for (var client in waitingClientsForData){
    client.add("$wsLoginDataHeader;$httpServerIdentity;$rawData");
  }
  if (isThereAVote()){
    for (var client in waitingClientsForData){
      client.add("${wsLoginVoteHeader};${httpServerIdentity};$currentVote");
    }
  }
  waitingClientsForData.clear();
}

/// Function which is called when the mpStartVoteHeader is received and send the startVote message to all connected web clients
///
/// Takes a String which represents the SENDER field of a network message and a String which represents the DATA field of a network message
/// Takes the Socket which represents the MP socket to send the confirmation message
void startVote(String sender, String rawData, Socket masterSocket){

  currentVote = rawData;
  currentVoteInfo = {};
  for (var client in clients.keys){
    client.add("${startVoteHeader};${httpServerIdentity};$rawData");
  }
  masterSocket.write("${voteOkHeader};${httpServerIdentity};null");
}

/// Function which checks if there is an ongoing vote, called when a user logs back in and needs jury data
bool isThereAVote(){
  return currentVote != null;
}

/// Functions which checks if a user has the right to vote according to its JWT
bool hasTheRightToVote(String token){
  bool hasVoted = currentVoteInfo?.containsKey(token) ?? false;
  return checkJWT(token) == 0 && !hasVoted;
}

/// Function which is called when webClientVoteUpdate header is received, sends the vote update from the web client to the MP
///
/// Takes a String which represents the SENDER field of a network message and a String which represents the DATA field of a network message
/// Takes the Socket which represents the MP socket to send the vote update data
void sendVoteUpdate(String sender, String rawData, Socket masterSocket){
  Map<String,dynamic> data = jsonDecode(rawData);
  if (hasTheRightToVote(data["token"])){
    masterSocket.write("${voteUpdateHeader};${httpServerIdentity};${rawData}");
    currentVoteInfo?["token"] = data["token"];
  }
  else{
    print("Hasn't the right to vote");
  }
}


/// Function which is called when mpStopVoteHeader header is received, it broadcasts this message to all connected web clients
///
/// Takes a String which represents the SENDER field of a network message and a String which represents the DATA field of a network message
/// Takes the Socket which represents the MP socket to send the vote update data
void stopVote(String sender, String rawData, Socket masterSocket){
  currentVote = null;
  currentVoteInfo = null;
  for (var client in clients.keys){
    client.add("${stopVoteHeader};${httpServerIdentity};$rawData");
  }
  masterSocket.write("${voteEndHeader};${httpServerIdentity};null");
}

/// Function which is called when the mpSessionUpdate header is received, broadcasting the session update to all connected web clients
///
/// Takes a String which represents the SENDER field of a network message and a String which represents the DATA field of a network message
void sendSessionUpdate(String sender, String rawData){
  if (startedJury){
    for (var client in clients.keys){
      client.add("${sessionUpdateHeader};${httpServerIdentity};${rawData}");
    }
  }
}

/// Function which is called each time there is a new message on the MP Socket, it processes it by taking out the header and calling the appropriate function
///
/// Takes a List of integers (which represents raw bytes in Dart) which represents the message and a Socket which represents the MP Socket
void processMasterProgramMessage(List<int> data, Socket masterSocket){
  String receivedData = "";
  if (data.length > 2048 || sink.isNotEmpty){
    print("[NETWORK] - processMPMessages : Large data waiting for all the packets...");
    sink.write(utf8.decode(data));
    if (sink.toString().contains("\n")){
      print("[NETWORK] - processMPMessages : Last Character from data packet, now unpacking");
      print("[NETWORK] - processMPMessages : Sink ressembles to this, trying to decode it");
      receivedData = sink.toString();
      sink.clear();
    }
    else{
      print("[NETWORK] - processMPMessages : Still recieving packets");
      return;
    }
  } else{
    receivedData = utf8.decode(data);
  }

  List<String> decodedMessage = receivedData.split(";");
  if (decodedMessage.length < 3) throw Exception("Unrecognized format -> ${data}");
  String primitive = decodedMessage[0];
  String sender = decodedMessage[1];
  String rawData = decodedMessage[2];

  switch (primitive){
    case mpSessionDataHeader:
      print("[NETWORK] - Message type : Received Session Data");
      addSessionData(sender, rawData);
      masterSocket.write("${sessionDataReceivedHeader};${httpServerIdentity};");
      break;
    case mpInitDataHeader:
      print("[NETWORK] - Message type : Received initial Data");
      sendInitialData(sender, rawData,masterSocket);
      break;
    case mpLoginDataHeader:
      print("[NETWORK] - Message type : Getting data for logged back in users");
      sendDataToLoggedInUser(sender, rawData, masterSocket);
      break;
    case mpStartVoteHeader:
      print("[NETWORK] - Message type : Started vote process");
      startVote(sender, rawData, masterSocket);
      break;
    case mpStopVoteHeader:
      print("[NETWORK] - Message type : Started vote process");
      stopVote(sender, rawData, masterSocket);
      break;
    case mpSessionUpdate:
      print("[NETWORK] - Message type : Session update");
      sendSessionUpdate(sender, rawData);
      break;
    default:
      throw ("Unknown Header from Master program");

  }


}

/// Function that listens for webSockets connections and messages, calls the processWSMessage function each times a new message is received
///
/// Takes an HTTP Request which should be the WS request (throws an error otherwise), a Socket which represents the MP Socket
/// and the Dictionnary of all connected clients, to either add an entry it if there is a new client, or update an entry if a clients logs back in
Future<void> listenForWebSockets(HttpRequest request, Socket masterSocket, Map<WebSocket,Map<String,dynamic>>clients) async {
  print("[NETWORK] - New connection from WebSocket");
  if (WebSocketTransformer.isUpgradeRequest(request)){
    print("Connection info ${request.connectionInfo?.remoteAddress}");
    WebSocket clientSocket = await WebSocketTransformer.upgrade(request);
    clients[clientSocket] = {};
    clientSocket.listen(
        (data){
          print("[NETWORK] - New Message from ${request.connectionInfo?.remoteAddress.address}");
          processWebSocketMessage(data,clientSocket, masterSocket);
        }
    );

  }
  else{
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('Reserved to WebSockets')
      ..close();
  }
}

/// Function that listens for MP messages on the MP Socket, calls the processMasterProgramMessage function each times a new messages is received
///
/// Takes a Socket which represents the MP Socket
Future<void> listenForMasterProgram(socket) async{
  socket.listen((data){
    print("[NETWORK] - New message from Master Program");
    processMasterProgramMessage(data,socket);
  });
}

/// Middleware which force the navigator to not cache the app (doesn't work on Safari)
Middleware get _noCacheMiddleware {
  return (Handler innerHandler) {
    return (Request request) async {
      final response = await innerHandler(request);
      return response.change(headers: {
        ...response.headers,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      });
    };
  };
}

/// Function which broadcasts a messages to all connected web clients
///
/// Takes a String which represents the raw data to send
void broadcastMessageToWS(String data){
  for (MapEntry<WebSocket,Map<String,dynamic>> client in clients.entries){
    if (!client.value.containsKey("token")){
      print("Client without any token");
      continue;
    }
    if (checkJWT(client.value["token"]) == 0){
      client.key.add(data);
    }
  }
}

Future<InternetAddress> getNetworkInterfaceIp() async{
  NetworkInterface? selectedInterface;
  int selectedAdressIndex = -1;
  List<NetworkInterface> interfaces = await NetworkInterface.list();
  for (var interface in interfaces){
    print("----Interface Info----");
    print(interface.name);
    print(interface.addresses);
    InternetAddress? selectedAddress = interface.addresses.where((e) => !e.isLinkLocal && !e.isLoopback && (e.type != InternetAddressType.IPv6)).firstOrNull;
    if (selectedAddress != null){
      selectedAdressIndex = interface.addresses.indexOf(selectedAddress);
      selectedInterface = interface;
      break;
    }
    print("----------------------");
  }
  if (selectedInterface == null || selectedAdressIndex == -1){
    throw Exception("Unable to find an correct IP adress");
  }
  return selectedInterface.addresses[selectedAdressIndex];
}
/// Main function which is the entrypoint of the program
void main() async{

  // Trying to establish a connection with the Master program
  socket = await Socket.connect(masterProgamIP, masterProgramPORT);
  print("Connected to mob'INSA software");
  // Sending a message to acknowledge that we are indeed connected to the MP
  print(httpInitRawData);
  InternetAddress selectedAdress = await getNetworkInterfaceIp();
  httpInitRawData = '{"name" :"MobINSAHTTPServer - v1.0.0", "ipaddr" : "${selectedAdress.address}", "hostaddr" : "${Platform.localHostname}"}';
  socket.write("$httpInitHeader;$httpServerIdentity;$httpInitRawData");
  // Generating the X509 certificate for establishing an HTTPS connection with web clients
  await generateCertificateWithBasicUtils();
  // Retrieving the generated certificate
  final context = SecurityContext()
    ..useCertificateChain('cert.pem')
    ..usePrivateKey('key.pem');
  // Starting to listen to the master program messages
  listenForMasterProgram(socket);
  // Waiting to receive the sessionData from the master program
  bool sessionDataStatus = await receivedSessionData.future;
  // If the sessionDataStatus is false, it means there was an error involving the session data retrieval process
  if (!sessionDataStatus){
    throw Exception("No Session Data was received");
  }
  String webPath = Platform.isMacOS ? "${Platform.resolvedExecutable}/web" : "web";
  // Creating the static handler for having a HTTP Server
  final staticHandler = createStaticHandler(
    webPath,
    defaultDocument: 'index.html',
  );
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_noCacheMiddleware)
      .addHandler(staticHandler);

  late HttpServer server;
  // if in a debug environment, serve the webapp with HTTP
  if (DEBUG){
    server = await HttpServer.bind(httpIP, httpPORT);
  }
  // Else, use HTTPS for TLS encryption
  else{
    server = await HttpServer.bindSecure(httpIP, httpPORT,context);
  }

  print("Started HTTP Server");
  // Process each HTTP request and furnish the associated response
  await for (HttpRequest request in server){
    if (request.uri.path == '/ws'){
      listenForWebSockets(request, socket, clients);
    }
    else{
      shelf_io.handleRequest(request,handler);
    }
  }
}