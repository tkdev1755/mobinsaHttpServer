import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:vmservice_io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' hide ECPrivateKey, ECPublicKey, RSAPrivateKey;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:basic_utils/basic_utils.dart';
import 'KeychainAPI/keyring.dart';
import 'certificateGenerator.dart';

final Keyring keyring = Keyring();
const String httpServiceName = "mobinsaHTTPServer";
const String httpUsername = "mobInsaJwtKey";
final masterProgamIP = InternetAddress.loopbackIPv4;
final PORT = 7070;
final httpIP = InternetAddress.anyIPv4;
final httpPORT = 8080;
/// OWN HTTP SERVER HEADERS
// Headers that are used to communicate with the Master Program
const httpServerIdentity = "mHTTPServerV1.0.0";
const httpInitHeader = "httpInit";
const httpInitRawData = "MobINSAHTTPServer - v1.0.0";
const String sessionDataReceivedHeader = "fSessionData";
const String newUserHeader = "newUser";
const String loginDataHeader = "loginGetData";
const String initDataSentHeader = "fInitData";
const String voteOkHeader = "voteOk";
const String voteEndHeader = "voteEndOk";
// Headers that are used for communicating with WS
const String connectedInHeader = "connOk";
const String connectErrorHeader = "connError";
const String loginErrorHeader = "logInError";
const String loginOkHeader = "loginOk";
const String initDataHeader = "initDataSend";
const String wsLoginDataHeader = "loginDataSend";
const String wsLoginVoteHeader = "loginVoteData";
const String startVoteHeader = "startVote";
const String stopVoteHeader = "stopVote";
const String voteUpdateHeader = "voteUpdate";
const String sessionUpdateHeader = "sessionUpdate";
/// END OF HTTP SERVER HEADERS

///  MASTER PROGRAM HEADERS
///  mp stands for Master Program
const mpSessionDataHeader = "sessionDataExchange";
const mpInitDataHeader = "initData";
const mpStartVoteHeader = "startVote";
const mpStopVoteHeader = "closeVote";
const mpLoginDataHeader = "loginData";
const mpSessionUpdate = "sessionUpdate";
/// END OF MASTER PROGRAM HEADERS

/// WS SPECIFIC HEADERS
const webClientNewUserHeader = "newUser";
const webClientLogIn = "logIn";
const webClientVoteUpdate = "voteUpdate";
const webClientIdentity = "MobINSAWEBClient";
final wsHeaders = [webClientNewUserHeader,webClientLogIn];
/// END OF WS SPECIFIC HEADERS

final Map<WebSocket, Map<String,dynamic>> clients = {};
List<WebSocket> waitingClientsForData = [];
late Socket socket;
bool startedJury = false;
String? currentVote;
Map<String,dynamic>? currentVoteInfo;

Completer<bool> receivedSessionData = Completer<bool>();
String sessionPassword = "";
List<String> trustedEmails = [];

StringBuffer sink = StringBuffer();


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

void addUser(String sender, String rawData, Socket masterSocket,  WebSocket clientSocket){
  if (!clients.containsKey(clientSocket) || clients.values.where((e) => e["uid"] != null && e["uid"] == sender).isEmpty){
    print("User should have these emails ${trustedEmails} and this password ${sessionPassword}");
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

bool authenticate(email, password){
  return sessionPassword == password /*&& trustedEmails.contains(email)*/;
}

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

void sendInitialData(String sender, String rawData, Socket masterSocket){
  for (var client in clients.keys){
    client.add("$initDataHeader;$httpServerIdentity;$rawData");
  }
  masterSocket.write('${initDataSentHeader};${httpServerIdentity};{numberOfClients : ${clients.length}');
  startedJury = true;
}

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

void startVote(String sender, String rawData, Socket masterSocket){

  currentVote = rawData;
  currentVoteInfo = {};
  for (var client in clients.keys){
    client.add("${startVoteHeader};${httpServerIdentity};$rawData");
  }
  masterSocket.write("${voteOkHeader};${httpServerIdentity};null");
}

bool isThereAVote(){
  return currentVote != null;
}

bool hasTheRightToVote(String token){
  bool hasVoted = currentVoteInfo?.containsKey(token) ?? false;
  return checkJWT(token) == 0 && !hasVoted;
}

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

void stopVote(String sender, String rawData, Socket masterSocket){
  currentVote = null;
  currentVoteInfo = null;
  for (var client in clients.keys){
    client.add("${stopVoteHeader};${httpServerIdentity};$rawData");
  }
  masterSocket.write("${voteEndHeader};${httpServerIdentity};null");
}

void sendSessionUpdate(String sender, String rawData){
  if (startedJury){
    for (var client in clients.keys){
      client.add("${sessionUpdateHeader};${httpServerIdentity};${rawData}");
    }
  }
}

void processMasterProgramMessage(List<int> data,masterSocket){
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

Future<void> listenForMasterProgram(socket) async{
  socket.listen((data){
    print("[NETWORK] - New message from Master Program");
    processMasterProgramMessage(data,socket);
  });
}

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

void isAuthenticated(){

}

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
void main() async{
  const DEBUG = true;
  socket = await Socket.connect(masterProgamIP, PORT);
  print("Connected to mob'INSA software");
  socket.write("$httpInitHeader;$httpServerIdentity;$httpInitRawData");
  await generateCertificateWithBasicUtils();
  final context = SecurityContext()
    ..useCertificateChain('cert.pem') // certificat (ou chaîne complète)
    ..usePrivateKey('key.pem');
  listenForMasterProgram(socket);
  bool sessionDataStatus = await receivedSessionData.future;
  if (!sessionDataStatus){
    throw "No Session Data was received";
  }
  final staticHandler = createStaticHandler(
    'web',
    defaultDocument: 'index.html',
  );
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_noCacheMiddleware)
      .addHandler(staticHandler);

  late HttpServer server;
  if (DEBUG){
    server = await HttpServer.bind(httpIP, httpPORT);
  }
  else{
    server = await HttpServer.bindSecure(httpIP, httpPORT,context);
  }

  print("Started HTTP Server");
  await for (HttpRequest request in server){
    if (request.uri.path == '/ws'){
      listenForWebSockets(request, socket, clients);
    }
    else{
      shelf_io.handleRequest(request,handler);
    }
  }
}