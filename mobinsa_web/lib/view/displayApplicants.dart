
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobinsa_web/model/networkManager.dart';
import 'package:mobinsa_web/uiElements.dart';
import 'package:mobinsa_web/view/sessionProgressDialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../model/Choice.dart';
import '../model/School.dart';
import '../model/Student.dart';


class DisplayApplicants extends StatefulWidget {
  final SessionHandler sessionHandler;

  const DisplayApplicants({super.key, required this.sessionHandler});

  @override
  State<DisplayApplicants> createState() => _DisplayApplicantsState();
}

class _DisplayApplicantsState extends State<DisplayApplicants> {
  Map<int,Student> students = {};
  Map<int,School> schools = {};
  Student? selectedStudent;
  Map<int, bool?> schoolChoices = {}; // null = pas de choix, true = accepté, false = refusé
  Map<int, bool> showCancelButton = {}; // true = afficher le bouton annuler, false = afficher les boutons accepter/refuser
  int currentStudentIndex = -1;
  List<bool> expandedStudentsChoice = [false,false,false];
  Color disabledColor = Colors.grey[100]!;
  String comment = "";
  bool hasSaved = false;
  String? currentSaveName;
  bool _showSaveMessage = false;
  bool loadedData = false;
  static const String netChoiceAccept = "choiceAccepted";
  static const String netChoiceRefusal = "choiceRefused";
  static const String netCancelAction = "choiceActionCancel";
  bool _showVoteUpdateMessage = false;
  String voteUpdateMessage = "";
  String voteUpdateStudent = "";
  int voteUpdateStudentID = -1;
  Color? voteUpdateColor = Colors.grey;
  final PageController _controller = PageController();

  void resetVoteMessage(){
    _showVoteUpdateMessage = false;
    print("RESETVOTE MESSAGE - Resetting everything");
    Future.delayed(Duration(milliseconds: 700), (){
      voteUpdateMessage = "";
      voteUpdateStudent = "";
      voteUpdateStudentID = -1;
      voteUpdateColor = Colors.grey;
    });
  }
  void onVoteStart(Map<String,dynamic> data, {bool fromLogin=false}){
    print("vote data -> $data");
    if ((data.containsKey("voteType") && data["voteType"] == "choiceVote")){
      if (!data.containsKey("studentID")){
        throw Exception("No student id for choiceVote");
      }
      int studentID = data["studentID"];
      print(students[studentID]);
      if (!students.keys.contains(studentID)){
        throw Exception("Student ID doesn't exists for choice Vote");
      }
      students[studentID]?.initializeNetworkData(data["voteType"]);
      if (fromLogin){
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          focusStudent(studentID);
        });
      }
      else{
        focusStudent(studentID);
      }
    }
    else if ((data.containsKey("voteType") && data["voteType"] == "matchVote")){

    }
    else{
      throw Exception("Bad json data from vote start info");
    }

  }

  void onVoteStop(Map<String,dynamic> data){
    if ((data.containsKey("voteType") && (data["voteType"] == "choiceVote" || data["voteType"] == "matchVote"))){
      if (!data.containsKey("studentID")){
        throw Exception("No student id for choiceVote");
      }
      int studentID = data["studentID"];
      print(students[studentID]);
      if (!students.keys.contains(studentID)){
        throw Exception("Student ID doesn't exists for choice Vote");
      }
      students[studentID]?.clearNetworkData();
      setState(() {

      });
    }
    else{
      throw Exception("Bad json data from vote start info");
    }
  }

  void focusStudent(int id, {bool fromVoteUpdate=false}){
    int index = students.keys.toList().indexOf(id);
    print("From vote update ? ${fromVoteUpdate}");
    print("Index associated to id ${id} is ${index}");
    selectStudentByIndex(index, fromID: true, id: id);
  }


  Color interrankingColor(List<MapEntry<int,Student>> students, int index){
    if(index!=0){
      if(students[index].value.get_min_rank()>students[index-1].value.get_min_rank()){
        return Colors.red;
      }
      if(students[index].value.get_min_rank()==students[index-1].value.get_min_rank()){
        return Colors.orange;
      }
    }
    if(index!=students.length-1){
      if(students[index].value.get_min_rank()<students[index+1].value.get_min_rank()){
        return Colors.red;
      }
      if(students[index].value.get_min_rank()==students[index+1].value.get_min_rank()){
        return Colors.orange;
      }
    }
    if(currentStudentIndex==index){
      return Colors.blue[900] ?? Colors.blue;
    }
    return Colors.black;
  }
  Future<bool>? initializedNetworkManager;
  List<bool> _startNetworkSession = [false];
  String getAutoRejectionComment(Student currentStudent){
    Map<int, List<bool>> rejectionReasons = currentStudent.choices.map((k,v) => MapEntry(k, v.getRejectionReasons()));
    rejectionReasons.removeWhere((k,v) => currentStudent.refused.contains(currentStudent.choices[k]));
    print("rejectionReasonlength ${rejectionReasons.length}");

    // On compte le nombre de voeux refusé automatiquement pour cause d'une mauvaise spécialisation
    int numberOfBadSpecialization = 0;
    // on compte le nombre de voeux refusés automatiquement pour cause d'un manque de place sur le niveau de l'élève
    int numberOfNoMoreSlots = 0;
    for (var value in rejectionReasons.values){
      // Si la valeur de la liste à l'index 0 est vraie, l'étudiant a la spécialisation nécessaire, selon la fonction Choice().getRejectionReasons
      numberOfBadSpecialization = numberOfBadSpecialization + (value[0] ? 0:1);
      // Si la valeur de la liste à l'index 1 est vraie, l'école à encore des places
      numberOfNoMoreSlots = numberOfNoMoreSlots + (value[1] ? 0:1);
    }
    final String numberOfSlotsComment = numberOfNoMoreSlots == 0 ? "" : "- ${numberOfNoMoreSlots == rejectionReasons.length ? "Tous ses voeux restants n'ont" : "$numberOfNoMoreSlots de ses voeux restants n'ont"} plus de places";
    final String numberOfBadSpecComment = numberOfBadSpecialization == 0 ? "" : "${numberOfNoMoreSlots != 0 ? "\n" : ""}" "- ${numberOfBadSpecialization == rejectionReasons.length ? "Tous ses voeux restants" : "$numberOfBadSpecialization de ses voeux restants"} ne prennent pas de ${currentStudent.get_next_year()}";
    print("Auto generated comment -> " "${numberOfSlotsComment + numberOfBadSpecComment}");
    return numberOfSlotsComment + numberOfBadSpecComment;
  }
  double getSessionProgress(){
    double progress = students.values.where((e) => e.accepted != null || e.hasNoChoiceLeft()).length / students.length;
    return progress;
  }
  bool checkIfChoiceVoteStarted(){
    return widget.sessionHandler.hasStartedVote && widget.sessionHandler.voteInfo.containsKey("studentID") && widget.sessionHandler.voteInfo.containsKey("voteType") && widget.sessionHandler.voteInfo["voteType"] == "choiceVote";
  }
  int getCurrentStudentVote(){
    return checkIfChoiceVoteStarted() ?  widget.sessionHandler.voteInfo["studentID"] : -1;
  }

  int getCurrentVoteStudentIndex({bool fromVoteUpdate=false}){
    return (checkIfChoiceVoteStarted() || fromVoteUpdate)?  (students.keys.toList().indexOf(widget.sessionHandler.voteInfo["studentID"])) : -1;
  }
  void onSessionUpdate(Map<String,dynamic> data){
    if (!data.containsKey("updateType") || !data.containsKey("selectedChoice") || !data.containsKey("selectedStudent")){
      throw Exception("Missing headers for function to be executed properly");
    }
    if (!students.containsKey(data["selectedStudent"])){
      throw Exception("Trying to apply a choice update on a non-existing student");
    }
    print("${students[data["selectedStudent"]]!.choices} and ${data["selectedChoice"]}");
    if (!(students[data["selectedStudent"]]!.choices.containsKey(data["selectedChoice"]))){
      throw Exception("Trying to apply a choice update on a non-existing choice");
    }
    int studentID = data["selectedStudent"];
    int choiceID = data["selectedChoice"];
    Student selectedStudent = students[studentID]!;
    Choice selectedChoice = selectedStudent.choices[choiceID]!;
    switch (data["updateType"]){
      case _DisplayApplicantsState.netChoiceAccept:
        schoolChoices[choiceID] = true;
        selectedChoice.accepted(selectedChoice.student);
        voteUpdateMessage = "A eu son voeu pour ${selectedChoice.school.name}";
        voteUpdateStudent = selectedStudent.name;
        voteUpdateStudentID = selectedStudent.id;
        voteUpdateColor = Colors.green[400];
        _showVoteUpdateMessage = true;
        showCancelButton[choiceID] = true;
        if (mounted){
          setState(() {

          });
        }
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              resetVoteMessage();
            });
          }
        });
        break;
      case _DisplayApplicantsState.netChoiceRefusal:
        schoolChoices[choiceID] = false;
        selectedChoice.refuse();
        showCancelButton[choiceID] = true;
        voteUpdateMessage = "A été refusé pour ${selectedChoice.school.name}";
        voteUpdateStudent = selectedStudent.name;
        voteUpdateStudentID = selectedStudent.id;
        voteUpdateColor = Colors.red[400];
        _showVoteUpdateMessage = true;
        if (mounted) {
          setState(() {

          });
        }
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              resetVoteMessage();
            });
          }
        });
        break;
      case _DisplayApplicantsState.netCancelAction:
        showCancelButton[choiceID] = false;
        schoolChoices[choiceID] = null;
        // Annuler l'action précédente
        if (selectedChoice.student.accepted == selectedChoice) {
          voteUpdateMessage = "N'as plus son choix ${selectedChoice.school.name}";
          selectedChoice.remove_choice();
        }
        // Restaurer le choix si il avait été refusé
        if (selectedChoice.student.refused.contains(selectedChoice)) {
          voteUpdateMessage = "Peut avoir ${selectedChoice.school.name} de nouveau";
          selectedChoice.student.restoreRefusedChoice(selectedChoice, choiceID);
        }
        voteUpdateStudent = selectedStudent.name;
        voteUpdateColor = Colors.orange[400];
        voteUpdateStudentID = selectedStudent.id;
        _showVoteUpdateMessage = true;
        if (mounted){
          setState(() {

          });
        }
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              resetVoteMessage();
            });
          }
        });
        break;
    }
  }
  int _currentPage = 0;
  int _currentSchool = 0;
  List<String> schoolsList = ["Syddansk Universtet - Erasmus", "UNIVERSITY COLLEGE OF SOUTHEAST NORWAY - ERASMUS SMS - OUTGOING","HES-SO Haute École Spécialisée de Suisse Occidentale - ERASMUS"];
  @override
  void initState() {
    // TODO: implement initState
    widget.sessionHandler.onVoteStart = onVoteStart;
    widget.sessionHandler.onSessionUpdate = onSessionUpdate;
    widget.sessionHandler.onVoteStop = onVoteStop;
    Timer.periodic(Duration(seconds: 10), (Timer timer) {
      if (loadedData){
        timer.cancel();
      }
      if (_currentPage < 1) {
        _currentSchool = (_currentSchool+1) % schoolsList.length;
        _currentPage++;
        setState(() {

        });
      } else {
        _currentPage = 0;
      }
      _controller.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    });
    super.initState();
  }
  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: "Mob'INSA - Voeux",
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          textTheme: GoogleFonts.montserratTextTheme(),
      ),
      home: Scaffold(

        appBar: AppBar(
          title: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: "Mob'",
                    style: UiText(matColor: Colors.black, weight: FontWeight.bold).mLargeText
                ),
                TextSpan(
                    text: "INSA",
                    style: UiText(matColor: Colors.red).mLargeText
                ),
              ],
            ),
          ),

          actions: [
            AnimatedOpacity(
              opacity: _showSaveMessage ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: UiShapes().frameRadius,
                ),
                child: Text(
                  "Fichier enregistré !",
                  style: UiText(color: UiColors.white).smallText,
                ),
              ),
            ),
            Padding(padding: EdgeInsets.only(left: 10)),
            Padding(padding: EdgeInsets.only(left: 10)),

            Padding(padding: EdgeInsets.only(left: 10)),
            /*IconButton(
              icon: Icon(PhosphorIcons.house(PhosphorIconsStyle.regular), size: 32.0),
              onPressed: () => {
                widget.schools.clear(),
                widget.students.clear,
                Navigator.pop(
                  context,
                ),
                Navigator.pop(
                  context,
                )
              },
              tooltip: "Revenir à la page d'accueil",
            ),*/
          ],
          backgroundColor: disabledColor,
        ),
        body: FutureBuilder(
          future: widget.sessionHandler.importedData,
          builder: (context, asyncSnapshot) {
            if (asyncSnapshot.hasData){
              if (!loadedData){
                  Map<String,dynamic> decodedData = SessionHandler.deserializeData(widget.sessionHandler.sessionData);
                  students = decodedData["students"];
                  schools = decodedData["schools"];
                  print("Students length ${students.length}");
                  print("Schools length ${schools.length}");
                  loadedData = true;
                  if (widget.sessionHandler.voteToGet){
                    print("Loading back vote data");
                    onVoteStart(widget.sessionHandler.voteInfo, fromLogin: widget.sessionHandler.voteToGet);
                    widget.sessionHandler.voteToGet = false;
                  }
              }
              List<MapEntry<int, Student>> studentEntries = students.entries.toList();
              List<MapEntry<int, School>> schoolsEntries = schools.entries.toList();
              return Stack(
                children: [
                  Row(
                    children: [
                      // Sidebar (20% de la largeur)
                      Container(
                        width: MediaQuery.of(context).size.width * 0.2,
                        decoration: BoxDecoration(
                          color: const Color(0xFFf5f6fa), // Couleur douce
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha((0.15 * 255).toInt()),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(2, 0),
                            ),
                          ],
                        ),
                        child: ListenableBuilder(
                          listenable: widget.sessionHandler,
                          builder: (BuildContext context,Widget? child) {
                            return Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: ListView.builder(
                                itemCount: studentEntries.length,
                                itemBuilder: (context, index) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12.0,left: 5,right: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: currentStudentIndex == index
                                            ? Colors.blueAccent
                                            : Colors.grey[300]!,
                                        width: 2,
                                      ),
                                    ),
                                    elevation: currentStudentIndex == index ? 8 : 2,
                                    color: currentStudentIndex == index
                                        ? const Color.fromARGB(255, 120, 151, 211)
                                        : (checkIfChoiceVoteStarted() && index == getCurrentVoteStudentIndex() )
                                        ? Colors.lightBlueAccent
                                        : (studentEntries[index].value.accepted != null
                                        ? const Color.fromARGB(255, 134, 223, 137)
                                        : studentEntries[index].value.refused.length == studentEntries[index].value.choices.length
                                        ? const Color.fromARGB(255, 213, 62, 35)
                                        : studentEntries[index].value.hasNoChoiceLeft() ? Colors.orange.shade200: Colors.white),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: (){
                                        {
                                          setState(() {
                                            selectedStudent = studentEntries[index].value;
                                            currentStudentIndex = index;
                                            schoolChoices.clear();
                                            expandedStudentsChoice = List.generate(
                                                studentEntries[index].value.choices.values.toList().length,
                                                    (_) => false
                                            );
                                            showCancelButton.clear();
                                            studentEntries[index].value.choices.forEach((key, choice) {
                                              bool isNetworkDataInitialized = choice.student.networkData != null && choice.student.networkData!.containsKey("choosenChoice");
                                              bool cancelChoice =  isNetworkDataInitialized && choice.student.networkData!["choosenChoice"] == key && choice.student.networkData!["choosenChoice"] != -1;
                                              showCancelButton[key] = (choice.student.accepted == choice) ||
                                                  choice.student.refused.contains(choice) || cancelChoice;
                                              if (choice.student.accepted == choice) {
                                                schoolChoices[key] = true;
                                              } else if (choice.student.refused.contains(choice)) {
                                                schoolChoices[key] = false;
                                              }
                                            });
                                          });
                                        }
                                      },
                                      child: ListTile(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                studentEntries[index].value.name,
                                                style: GoogleFonts.montserrat(textStyle : TextStyle(
                                                  fontSize: 14,
                                                  color: currentStudentIndex == index
                                                      ? const Color.fromARGB(255, 242, 244, 246)
                                                      : Colors.black,
                                                  fontWeight: currentStudentIndex == index ? FontWeight.bold : FontWeight.normal,
                                                )),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Padding(padding: EdgeInsets.only(right: 10)),
                                            Text(
                                              studentEntries[index].value.get_max_rank().toStringAsFixed(2),
                                              style: GoogleFonts.montserrat(textStyle : TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: interrankingColor(studentEntries,index),
                                              )),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }
                        ),
                      ),
                      // Contenu principal (80% de la largeur)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(255, 195, 188, 186).withAlpha((0.08 * 255).toInt()),
                                spreadRadius: 2,
                                blurRadius: 12,
                                offset: const Offset(-2, 0),
                              ),
                            ],
                          ),
                          child: selectedStudent != null
                              ? SingleChildScrollView(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section nom/prénom/promo
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Nom et promo à gauche
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${selectedStudent?.name}',
                                            style:  GoogleFonts.montserrat(textStyle: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            )),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${selectedStudent?.year}A ${selectedStudent?.departement}',
                                            style: GoogleFonts.montserrat(textStyle : TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            )),
                                          ),
                                          UiShapes.bPadding(20),
                                          Visibility(
                                            child: notificationCard(selectedStudent!),
                                            visible : selectedStudent?.refused.length != selectedStudent?.choices.length && (selectedStudent?.accepted == null) &&(selectedStudent?.hasNoChoiceLeft() ?? false) ,
                                          ),

                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    // Informations sur l'élève à droite
                                    Expanded(
                                      flex: 1,
                                      child: StudentInfoCard(selectedStudent!),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 30),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Section Écoles (gauche)
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ListenableBuilder(
                                            listenable : widget.sessionHandler,
                                            builder: (BuildContext context, Widget? child) {
                                              return Visibility(
                                                visible : widget.sessionHandler.hasStartedVote && (getCurrentStudentVote() == selectedStudent?.id),
                                                child: Container(
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    color: Colors.lightBlueAccent.shade700,
                                                    borderRadius: UiShapes().frameRadius,
                                                  ),
                                                  padding: EdgeInsets.all(20),
                                                  child: Text("Veuillez voter pour un des voeux", style: UiText(color: UiColors.white).mediumText,),
                                                ),
                                              );
                                            }
                                          ),
                                          UiShapes.bPadding(20),
                                          // Liste des écoles
                                          ...selectedStudent!.choices.entries.map((entry) {
                                            int index = entry.key;
                                            //Map<String, String> school = entry.value;
                                            return choiceCard(entry.value, index,expandedStudentsChoice,selectedStudent!);
                                          }),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 20),

                                    // Section Boutons d'action (droite)
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        children: [
                                          // Bouton Laisser un commentaire
                                          Container(
                                            width: double.infinity,
                                            height: 60,
                                            margin: const EdgeInsets.only(bottom: 16),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext dialogContext) => CommentModal(student: selectedStudent!, choice: null),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: Text(
                                                'Laissez un commentaire',
                                                style: GoogleFonts.montserrat( textStyle: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                )),
                                              ),
                                            ),
                                          ),

                                          // Bouton Revenir à l'étudiant précédent
                                          Container(
                                            width: double.infinity,
                                            height: 50,
                                            margin: const EdgeInsets.only(bottom: 16),
                                            child: ElevatedButton(
                                              onPressed: currentStudentIndex > 0
                                                  ? () => selectStudentByIndex(currentStudentIndex - 1)
                                                  : null, // Disable if we're at the first student
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey[300],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: Text(
                                                'Revenir à l\'étudiant précédent',
                                                style: GoogleFonts.montserrat(textStyle: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 14,
                                                )),
                                              ),
                                            ),
                                          ),

                                          // Bouton Passer à l'étudiant suivant
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton(
                                              onPressed: currentStudentIndex < students.length - 1
                                                  ? () => selectStudentByIndex(currentStudentIndex + 1)
                                                  : null, // Disable if we're at the last student
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey[300],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: Text(
                                                'Passer à l\'étudiant Suivant',
                                                style: GoogleFonts.montserrat(textStyle: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 14,
                                                )),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(bottom : 40),
                                          ),
                                          progressCard()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                              :  Center(child: Text("Sélectionnez un étudiant",style: UiText().mediumText,)),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: voteUpdateMessageWidget()
                  ),
                ],
              );
            }
            else{
              return Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 60,
                            height: 60,
                            child: const CircularProgressIndicator(
                              strokeWidth: 6,
                            )),
                        UiShapes.bPadding(20),
                        Text('En attente du chargement du jury',style: UiText().largeText,),
                      ],
                    ),
                    Center(
                      child: Card(
                        child: Container(
                          padding: EdgeInsets.all(20),
                          width : 400,
                          height: 300,
                          child : Center(
                            child: PageView(
                              controller: _controller,
                              children: [
                                tip1Widget(),
                                tip2Widget(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              );
            }
          }
        ),
      ),
    );
  }
  void selectStudentByIndex(int index, {bool fromID=false, int? id}) {
    print("fromID = ${fromID} -> value ? ${id}");
    if (index >= 0 && index < students.length) {
      print("this is the researched student ${students[index]}");
      int selectedID = students.keys.toList()[index];
      setState(() {
        if (fromID && id != null){
          selectedStudent = students[id];
          print("Selected student by ID from keys of map");
        }
        else{
          selectedStudent = students[students.keys.toList()[index]];
          print("Selected Student by index from list");

        }
        currentStudentIndex = index;
        print("CURRENT STUDENT INDEX IS $selectedID");
        expandedStudentsChoice = List.generate(
            students[selectedID]!.choices.values.toList().length,
                (_) => false
        );
        // Initialiser showCancelButton pour chaque choix en fonction de l'état actuel
        showCancelButton.clear();
        students[selectedID]!.choices.forEach((key, choice) {
          // Afficher le bouton annuler si le choix est accepté ou refusé
          showCancelButton[key] = (choice.student.accepted == choice) ||
              choice.student.refused.contains(choice);
          // Initialiser schoolChoices en fonction de l'état
          if (choice.student.accepted == choice) {
            schoolChoices[key] = true;
          } else if (choice.student.refused.contains(choice)) {
            schoolChoices[key] = false;
          }
        });
      });
    }
  }

  bool disableChoice(Choice choice, int index){
    int availableplaces = choice.student.get_graduation_level() == "master" ? choice.school.m_slots : choice.school.b_slots;
    bool isNetworkDataInitialized = choice.student.networkData != null && choice.student.networkData!.containsKey("choosenChoice");
    return (choice.student.accepted != null &&  choice.student.accepted != choice) ||
        (availableplaces == 0 && choice.student.accepted == null) || (isNetworkDataInitialized && choice.student.networkData!["choosenChoice"] != index && choice.student.networkData!["choosenChoice"] != -1 );
  }

  bool hasSelectedChoice(Choice choice, int index){
    return (choice.student.accepted != null && choice.student.accepted == choice);
  }

  bool disableChoiceByRanking(Student student_f,int choiceNumber){
    Map<int, List<Student>> ladder = student_f.ladder_interranking(students.values.toList());
    bool atLeastOneNotAccepted = false;
    /*print("meilleur: ${ladder}");
    print("-----------------------------------------------------------------");
    for (var entry in ladder.entries){
      for (var student in entry.value){
        print("student: ${student.name}");
        print("accepted: ${student.accepted}");
        print("refused: ${student.refused}");
        print("choice_f: ${student_f.choices[choiceNumber]}");
      }
    }
    print("-----------------------------------------------------------------");*/
    //pour s'il y a au moins un étudiant mieux classé qui n'est pas accepté.
    for (var entry in ladder.entries){
      if (entry.value.any((student) => student.accepted == null && !student.refused.contains(student_f.choices[choiceNumber]))){
        atLeastOneNotAccepted = true;
        break;
      }
    }
    return  atLeastOneNotAccepted && ladder.containsKey(choiceNumber);
  }

  Widget StudentInfoCard(Student selectedStudent){
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Classement S1", style: UiText().smallText,),
                    Text("${selectedStudent.ranking_s1}",
                      style:  GoogleFonts.montserrat(textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      )),
                    )
                  ],
                ),
              ),
              Padding(padding: EdgeInsets.only(right: 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Crédits ECTS",),
                    Text("${selectedStudent.ects_number}",
                      style: GoogleFonts.montserrat(textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color : (selectedStudent.ects_number < 30 ?
                        Colors.orange :
                        Colors.black),
                      )),
                    )
                  ],
                ),
              ),
              Padding(padding: EdgeInsets.only(right: 20)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Niveau d'anglais",style: UiText().smallText,),
                    Text(selectedStudent.lang_lvl,
                      style:  GoogleFonts.montserrat(textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      )),
                    )
                  ],
                ),
              ),
              Padding(padding: EdgeInsets.only(right: 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Heures d'absences", style : UiText().smallText),
                    Text("${selectedStudent.missed_hours}",
                      style: GoogleFonts.montserrat(textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color : (selectedStudent.missed_hours >= 5 ?
                        (selectedStudent.missed_hours >= 10 ? Colors.red : Colors. orange) :
                        Colors.black),
                      )),
                    )
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget choiceCard(Choice choice, int index, List<bool> expanded, Student selectedStudent,{bool overrideNetworkVote=false}) {
    int availablePlaces = choice.student.get_graduation_level() == "master" ? choice.school.m_slots : choice.school.b_slots;

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      color: hasSelectedChoice(choice, index) ? Colors.green[100] : disableChoice(choice,index) ? disabledColor : Colors.grey[300],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          // vsync: this,
          child : Visibility(
              visible: expanded[index-1],
              // Minimized view
              replacement:  Container(
                width: MediaQuery.sizeOf(context).width * 0.4,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                  minWidth: MediaQuery.sizeOf(context).width * 0.5,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            child: Text(
                              choice.school.name,
                              style: GoogleFonts.montserrat(textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              )),
                            ),
                          ),
                          Text(
                            choice.school.country,
                            style: GoogleFonts.montserrat(textStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            )),
                          ),
                        ],
                      ),
                    ),
                    UiShapes.rPadding(20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              expanded[index-1] = true;
                            });
                          },
                          icon: Icon(PhosphorIcons.arrowDown()),
                        ),
                        Padding(padding: EdgeInsets.only(bottom: 10)),
                        ListenableBuilder(listenable: widget.sessionHandler, builder:(BuildContext context, Widget? child){
                          if (((widget.sessionHandler.hasStartedVote || overrideNetworkVote) && (showCancelButton[index] ?? false) && selectedStudent?.id == getCurrentStudentVote())){
                            return cancelVote(choice, index, availablePlaces);
                          }
                          else if ((widget.sessionHandler.hasStartedVote && selectedStudent.id == getCurrentStudentVote()) || overrideNetworkVote){
                            return voteForChoice(choice, index, availablePlaces, selectedStudent, overrideNetworkVote: overrideNetworkVote);
                          }
                          else {
                            return Container();
                          }
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              // Expanded View
              child : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          choice.school.name,
                          style:  GoogleFonts.montserrat(textStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          )),
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: (){
                              setState(() {
                                expandedStudentsChoice[index-1] = false;
                              });
                            },
                            icon: Icon(PhosphorIcons.arrowUp()),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    choice.school.country,
                    style: GoogleFonts.montserrat(textStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    )),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Niveau académique requis",style: UiText().smallText,),
                                SizedBox(
                                  width: MediaQuery.sizeOf(context).width*0.5*0.4,
                                  child: Text(choice.school.academic_level,
                                    style:  GoogleFonts.montserrat(textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    )),
                                  ),
                                ),
                                Padding(padding: EdgeInsets.only(bottom: 5)),
                                Text("Langue d'enseignement", style: UiText().smallText,
                                ),
                                SizedBox(
                                  width: MediaQuery.sizeOf(context).width*0.5*0.4,
                                  child: Text(choice.school.use_langage,
                                    maxLines: 3,
                                    style: GoogleFonts.montserrat(textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    )),
                                  ),
                                ),
                                Padding(padding: EdgeInsets.only(bottom: 5)),
                                Text("Niveau de langue",style: UiText().smallText,),
                                SizedBox(
                                  width: MediaQuery.sizeOf(context).width*0.5*0.4,
                                  child: Text("${choice.school.req_lang_level}",
                                    style: GoogleFonts.montserrat(textStyle: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                    )),
                                    maxLines: 4,
                                  ),
                                ),
                              ],
                            ),
                            Padding(padding: EdgeInsets.only(right: 20)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Nombre de places",style: UiText().smallText,),
                                  Text("${choice.school.remaining_slots} | ${choice.school.b_slots} Bachelor, ${choice.school.m_slots} Master",
                                    style: GoogleFonts.montserrat(textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    )),
                                  ),
                                  Padding(padding: EdgeInsets.only(bottom: 5)),
                                  Text("Discipline",style: UiText().smallText,),
                                  SizedBox(
                                    width : MediaQuery.sizeOf(context).width*0.5*0.3,
                                    child: Text("${choice.school.specialization.toString().replaceAll("[", "").replaceAll("]", "")}",
                                      style: GoogleFonts.montserrat(textStyle: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color : (choice.is_incoherent() ?
                                        Colors.orange :
                                        Colors.black),

                                      )),
                                    ),
                                  ),
                                  Padding(padding: EdgeInsets.only(bottom: 5)),
                                  Text("Interclassement"),
                                  Text("${choice.interranking}",
                                    style:  GoogleFonts.montserrat(textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    )),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Afficher le bouton annuler ou les boutons accepter/refuser
                      ListenableBuilder(listenable: widget.sessionHandler, builder:(BuildContext context, Widget? child){
                        if (((widget.sessionHandler.hasStartedVote || overrideNetworkVote) && (showCancelButton[index] ?? false) && selectedStudent?.id == getCurrentStudentVote())){
                          return cancelVote(choice, index, availablePlaces);
                        }
                        else if ((widget.sessionHandler.hasStartedVote && selectedStudent.id == getCurrentStudentVote()) || overrideNetworkVote){
                          return voteForChoice(choice, index, availablePlaces, selectedStudent, overrideNetworkVote: overrideNetworkVote);
                        }
                        else {
                          return Container();
                        }
                      }),
                    ],
                  ),
                ],
              )
          ),
        ),
      ),
    );
  }


  Widget notificationCard(Student currentStudent){
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: UiShapes().frameRadius,
      ),
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(PhosphorIcons.info(),size: 50,),
          Padding(padding: EdgeInsets.only(right: 10)),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Cet étudiant n'as plus de voeux admissibles à cause des raisons suivantes :", style: UiText().nsText,),
              Text("${getAutoRejectionComment(currentStudent)}", style: UiText(weight: FontWeight.w500).nText,),
            ],
          ))
        ],
      ),
    );
  }

  Widget progressCard(){
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: UiShapes().frameRadius
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text("Avancement de la Séance", style: UiText().nText,)),
              Padding(padding: EdgeInsets.only(right: 20)),
              IconButton(onPressed: (){
                showDialog(context: context, builder: (BuildContext context){
                  return SessionProgressDialog(students: students.values.toList(), schools: schools.values.toList());
                });
              }, icon: Icon(PhosphorIcons.info()))
            ],
          ),
          UiShapes.bPadding(10),
          Row(
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: getSessionProgress()),
                  duration: Duration(milliseconds: 200),
                  builder: (context, value, _) {
                    final progressColor = Color.lerp(Colors.red, Colors.green, value)!;
                    return LinearProgressIndicator(
                      borderRadius: UiShapes().frameRadius,
                      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      value: value,
                    );
                  },
                ),
              ),
              Padding(padding: EdgeInsets.only(right : 20)),
              SizedBox(
                  width: 90,
                  child: Text("${(getSessionProgress()*100).toStringAsFixed(1)}%", style: UiText().mediumText,))
            ],
          )
        ],
      ),
    );
  }

  Widget voteForChoice(Choice choice ,int index, availablePlaces, Student selectedStudent, {bool overrideNetworkVote=false}){
    bool isNetworkDataInitialized = choice.student.networkData != null && (choice.student.networkData?.containsKey("choosenChoice") ?? false);
    bool hasVotedForAnotherChoice = isNetworkDataInitialized && (choice.student.networkData?["choosenChoice"] != index ?? false) && (choice.student.networkData?["choosenChoice"]! != -1 ?? false);
    return SizedBox(
      width: 60,
      height: 60,
      child: Tooltip(
        message: availablePlaces == 0 ? "Plus de places disponibles pour ce voeu" : disableChoiceByRanking(selectedStudent!, index) ? "Il y un étudiant avec un meilleur interclassement" : "Voter pour ce choix",
        child: ElevatedButton(
          onPressed: disableChoiceByRanking(selectedStudent, index)  || choice.student.accepted != null || availablePlaces == 0 || hasVotedForAnotherChoice  ? null  : () {
            if (overrideNetworkVote){
              return;
            }
            setState(() {
              schoolChoices[index] = true;
              Map<String,dynamic> rawData = {
                "studentID" : "${selectedStudent.id}",
                "voteType" : "choiceVote",
                "action" : "addVote",
                "choice": index,
              };
              widget.sessionHandler.sendVote(rawData);
              selectedStudent!.updateNetworkData("choosenChoice", index);
              showCancelButton[index] = true;

            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: schoolChoices[index] == true
                ? Colors.green[700]
                : Colors.green,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
  Widget voteUpdateMessageWidget(){
    return AnimatedOpacity(
      opacity: _showVoteUpdateMessage ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: voteUpdateColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: voteUpdateStudent, style: UiText(color : UiColors.white, weight: FontWeight.w700).smallText),
                    TextSpan(text: " $voteUpdateMessage", style: UiText(color : UiColors.white).smallText)
                  ],
              ),
              maxLines: 4,
            ),
            UiShapes.bPadding(10),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                focusStudent(voteUpdateStudentID, fromVoteUpdate: true);
              },
              child: Text("Aller à cet étudiant",style: UiText(color: UiColors.white).smallText,),
            ),
          ],
        )
      ),
    );
  }
  Widget cancelVote(Choice choice, int index, int availablePlaces){
    return SizedBox(
      width: 80,
      height: 40,
      child: Tooltip(
        message: "Annuler l'action précédente",
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              showCancelButton[index] = false;
              schoolChoices[index] = null;
              // Annuler l'action précédente
              Map<String,dynamic> rawData = {
                "studentID" : "${selectedStudent!.id}",
                "voteType" : "choiceVote",
                "action" : "cancelVote",
                "choice": index,
              };
              widget.sessionHandler.sendVote(rawData);
              bool isNetworkDataInitialized = choice.student.networkData != null && choice.student.networkData!.containsKey("choosenChoice");
              if (isNetworkDataInitialized){
                choice.student.networkData!["choosenChoice"] = -1;
              }
              /*if (choice.student.accepted == choice) {
                                    choice.remove_choice();
                                  }*/
              // Restaurer le choix si il avait été refusé
              /*if (choice.student.refused.contains(choice)) {
                                    choice.student.restoreRefusedChoice(choice, index);
                                  }*/
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            "Annuler",
            style: GoogleFonts.montserrat(textStyle: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            )),
          ),
        ),
      ),
    );
  }

  Widget tip1Widget(){
    Student dummyStudent = Student
      (id: 0, name: "Jean", choices: {}, specialization: "4A GSI ", ranking_s1: 4, ects_number: 30, lang_lvl: "B1", missed_hours: 3, comment: "Hello");
    return Column(
      children: [
        StudentInfoCard(dummyStudent),
        Spacer(),
        Text("Étudiez les statistiques de chaque étudiant", style: UiText().mediumText,),
        UiShapes.bPadding(10),
      ],
    );
  }
  Widget tip2Widget(){
    School dummySchool = School(name: schoolsList[_currentSchool], country: "Danemark", content_type: "ERASMUS SMS", available_slots: 3, b_slots: 1, m_slots: 2, specialization: ["4A STI"], graduation_level: "Master", program: "", use_langage: "", req_lang_level: "", academic_level: "");
    Student dummyStudent = Student
      (id: 0, name: "Jean", choices: {}, specialization: "4A GSI ", ranking_s1: 4, ects_number: 30, lang_lvl: "B1", missed_hours: 3, comment: "Hello");
    Choice dummyChoice = Choice(school: dummySchool, interranking: 20, student: dummyStudent);
    dummyStudent.choices[1] = dummyChoice;
    return Column(
      children: [
        choiceCard(dummyChoice, 1, [false],dummyStudent, overrideNetworkVote: true),
        Spacer(),
        Text("Votez pour les voeux de chacun de vos étudiants", style: UiText().mediumText,),
        UiShapes.bPadding(10),
      ],
    );
  }
}

// Widget modal pour les commentaires
class CommentModal extends StatefulWidget {
  final Student student;
  final Choice? choice; // null pour commentaire général, non-null pour commentaire sur un choix spécifique

  const CommentModal({super.key, required this.student, this.choice});

  @override
  State<CommentModal> createState() => _CommentModalState();
}

class _CommentModalState extends State<CommentModal> {
  int selectedChoice = 1;
  String comment = "";

  @override
  void initState() {
    super.initState();
    // Si un choix est spécifié, utiliser son index
    if (widget.choice != null) {
      widget.student.choices.forEach((key, value) {
        if (value == widget.choice) {
          selectedChoice = key;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.choice != null ? "Commentaire sur le refus" : "Laisser un commentaire"),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.choice == null) // Afficher le dropdown seulement pour les commentaires généraux
            DropdownButton<int>(
              value: selectedChoice,
              items: [1, 2, 3].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text("Choix $value"),
                );
              }).toList(),
              onChanged: (int? newValue) {
                setState(() {
                  selectedChoice = newValue!;
                });
              },
            ),
          if (widget.choice == null) SizedBox(height: 16),
          TextField(
            onChanged: (value) {
              comment = value;
            },
            decoration: InputDecoration(
              hintText: widget.choice != null ? "Expliquez pourquoi ce choix a été refusé" : "Entrez votre commentaire",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text("Annuler"),
        ),
        TextButton(
          onPressed: () {
            if (widget.choice != null) {
              // Ajouter le commentaire au choix refusé
              widget.choice!.post_comment = comment;
            } else {
              // Ajouter le commentaire général
              widget.student.add_post_comment(selectedChoice, comment);
            }
            Navigator.pop(context);
          },
          child: Text("Valider"),
        ),
      ],
    );
  }
}