import 'package:mobinsa_web/model/School.dart';
import 'package:mobinsa_web/model/Student.dart';

class Choice {
  static String jsonSchool = "school";
  static String jsonInterranking = "interranking";
  static String jsonStudent = "student";
  static String jsonPostComment = "post_comment";
  School school;
  double interranking;
  Student student;
  String? post_comment;
  Choice ({required this.school, required this.interranking, required this.student});

  bool accepted(Student s) {
    //affectation d'une offre de séjour à un élève
    if (school.accepted(s)) {
      student.accepted = this;
      //print("ACCEPTED CHOICE");
      return true;
    }
    return false;
  }

  void refuse() {
    //refuser un choix et l'ajouter à la liste des choix refusés
    student.addRefusedChoice(this);
    // Retirer le choix de la liste des choix actifs
    if(student.accepted == this){
      remove_choice();
    }
    //print("REFUSED CHOICE");
    //print(student.refused);
  }

  void remove_choice() {
    student.accepted = null;
    school.add_slots(student);
  }

  bool is_incoherent(){
    if (!(school.specialization.contains(student.get_next_year()))){
      return true;
    }
    else {
      return false;
    }

  }

  Map<String, dynamic> toJson(){
    return {
      "school" : school.toJson(),
      "interranking" : interranking,
      "student" : student.id,
      "post_comment" : post_comment ?? "null",
    };
  }
  
  factory Choice.fromJson(Map<String,dynamic> json, Student student, List<School> schools){
    School school = schools.firstWhere((e) => e == School.fromJson(json[jsonSchool]));
    return Choice(school: school, interranking: json[jsonInterranking], student:  student);
  }

  @override
  String toString() {
    // Attention à ne pas imprimer student.toString() ici pour éviter une boucle infinie
    // si Student.toString() imprime aussi ses Choice qui impriment leur Student, etc.
    // Imprimez juste des informations clés de l'étudiant si nécessaire, ou son ID/nom.
    // return 'Choix{École: $school, Classement Inter.: $interranking}';
    return school.name;
  }


  bool isChoiceValid(){
    // On s'assure ici que 2 éléments sont vrai, disponibilité de la spécialisation chez l'école, et disponibilité des places
    bool hasSpecialization = school.specialization.contains(student.get_next_year());
    bool hasPlaces = school.getPlacesBySpecialization(student.get_graduation_level()) != 0;
    //print("IsChoiceValid : L'étudiant a-t-il la spécialisation nécessaire ? ${hasSpecialization} \n la formation as-t-elle encore des places ${hasPlaces}");
    return hasSpecialization && hasPlaces;
  }

  String getRejectionString(){
    bool hasSpecialization = getRejectionReasons()[0];
    bool hasPlaces = getRejectionReasons()[1];
    String finalString = "L'étudiant à été refusé car :" "${hasPlaces ? "" : "\nAbsence de places à l'établissement"}" "${hasSpecialization ? "":"\n Établissement ne recevant pas de ${student.get_next_year()}"}";
    return finalString;
  }

  List<bool> getRejectionReasons(){
    return [school.specialization.contains(student.get_next_year()),school.getPlacesBySpecialization(student.get_graduation_level()) != 0];
  }

  Choice clone(Student newStudent, {School? school}){
    return Choice(school: school ?? this.school.clone(),interranking:  interranking, student: newStudent);
  }
  @override
  bool operator ==(Object other) {
    // if (identical(this, other)) return true;
    if (other is! Choice) return false;
    // On considère que deux choix sont les mêmes s'ils ont la même école, on fait la distinction entre les étudiants plus tard

    return school.id == other.school.id;
  }




}