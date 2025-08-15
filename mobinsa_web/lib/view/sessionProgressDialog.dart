
import 'package:flutter/material.dart';
import 'package:mobinsa_web/uiElements.dart';
import '../../model/Choice.dart';
import '../../model/School.dart';
import '../../model/Student.dart';


class SessionProgressDialog extends StatelessWidget {
  final List<Student> students;
  final List<School> schools;
  const SessionProgressDialog({super.key, required this.students, required this.schools});

  double getSessionProgress(List<Student> students){
    double progress = getProcessedStudentNumber(students) / students.length;
    return progress;
  }
  int getProcessedStudentNumber(List<Student> students){
    int processedStudents = students.where((e) => e.accepted != null || e.hasNoChoiceLeft()).length;
    return processedStudents;
  }
  int getAcceptedStudentsByLevel(List<Student> students, int choiceRank){
    return students.where((e) => e.accepted != null && e.choices.entries.where((c) => c.value == e.accepted && c.key == choiceRank).isNotEmpty).length;
  }


  Map<String,int> getSecondBallotStudentNumber(List<Student> students){
    int secondBallotStudents = students.where((e) => e.accepted == null && e.hasNoChoiceLeft()).length;
    int allChoicesDeclinedStudentNumber = students.where((e) => e.choices.length == e.refused.length).length;
    int noPlaceInAnyChoiceStudentNumber = students.where((e) => e.choices.entries.where((e) => !(e.value.getRejectionReasons()[1])).length == e.choices.length && e.accepted == null && !(e.choices.length == e.refused.length) && !(e.choices.entries.where((e) => !(e.value.getRejectionReasons()[0])).length == e.choices.length) ).length;
    int allIncoherentChoiceStudentNumber = students.where((e) => e.choices.entries.where((e) => !(e.value.getRejectionReasons()[0])).length == e.choices.length && e.accepted == null).length;
    return {
      "allSecondBallotStudents":secondBallotStudents,
      "allChoiceDeclinedStudents" : allChoicesDeclinedStudentNumber,
      "noPlaceInAnyChoiceStudents" : noPlaceInAnyChoiceStudentNumber,
      "allIncoherentChoiceStudents" : allIncoherentChoiceStudentNumber,
    };
  }


  @override
  Widget build(BuildContext context) {
    int processedStudentsNumber = getProcessedStudentNumber(students);
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(20),
        width: 800,
        height: 510,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Avancement de la séance", style: UiText().largeText,),
            UiShapes.bPadding(10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex : 1,
                    child: StudentSecondBallotCard(context),
                  ),
                  UiShapes.rPadding(20),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Students1stAcceptedCard(context)),
                        UiShapes.bPadding(20),
                        Expanded(
                          child: Row(
                              children: [
                                Flexible(child: Student2ndAcceptedCard(context)),
                                UiShapes.rPadding(20),
                                Flexible(child: Student3rdAccepted(context)),
                              ]
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            UiShapes.bPadding(30),
            SessionProgressBar(context),
            UiShapes.bPadding(10),
            Text("$processedStudentsNumber étudiants traités / ${students.length} étudiants")
          ],
        ),
      ) ,
    );
  }
  Widget SessionProgressBar(context){
    double progress = getSessionProgress(students);
    return Row(
      children: [
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: getSessionProgress(students)),
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
        Text("${(progress*100).toStringAsFixed(1)}%", style: UiText().mediumText,)
      ],
    );
  }

  Widget Student3rdAccepted(context){
    return Container(
      padding: EdgeInsetsGeometry.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: UiShapes().frameRadius
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Étudiants ayant eu leur 3ème voeu",style: UiText().nsText,),
          Spacer(),
          Text("${getAcceptedStudentsByLevel(students, 3)}/${students.length}",style: UiText().vLargeText,)
        ],
      ),
    );
  }

  Widget Student2ndAcceptedCard(context){
    return Container(
      padding: EdgeInsetsGeometry.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: UiShapes().frameRadius
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Étudiants ayant eu leur 2ème voeu",style: UiText().nsText,),
          Spacer(),
          Text("${getAcceptedStudentsByLevel(students, 2)}/${students.length}",style: UiText().vLargeText,)
        ],
      ),
    );
  }

  Widget Students1stAcceptedCard(context){
    return Container(
      padding: EdgeInsetsGeometry.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: UiShapes().frameRadius
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Étudiants ayant leur 1er voeu",style: UiText().nsText,),
          Spacer(),
          Text("${getAcceptedStudentsByLevel(students, 1)}/${students.length}",style: UiText().vLargeText,),
          Spacer(),
        ],
      ),
    );
  }

  Widget StudentSecondBallotCard(context){
    Map<String, int> secondStats = getSecondBallotStudentNumber(students);
    return Flexible(
      flex: 1,
      child: Container(
        padding: EdgeInsetsGeometry.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: UiShapes().frameRadius
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Étudiants \nau second tour", style: UiText().nText,),
            Spacer(),
            Text("${secondStats["allSecondBallotStudents"]}/${students.length}",style: UiText(weight: FontWeight.w500).vvLargeText,),
            UiShapes.bPadding(10),
            Expanded(child: Text("${secondStats["allChoiceDeclinedStudents"]} à cause de refus sur tous les voeux")),
            UiShapes.bPadding(5),
            Expanded(child: Text("${secondStats["noPlaceInAnyChoiceStudents"]} à cause de manque de places")),
            UiShapes.bPadding(5),
            Expanded(child: Text("${secondStats["allIncoherentChoiceStudents"]} à cause de voeux incohérent (spécialité incorrecte)", overflow: TextOverflow.ellipsis,)),
          ],
        ),
      ),
    );
  }

}