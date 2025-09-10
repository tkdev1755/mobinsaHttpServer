import 'package:mobinsa_web/model/Choice.dart';
import 'package:mobinsa_web/model/School.dart';

class Student {
  static String jsonId = "id";
  static String jsonName = "name";
  static String jsonChoices = "choices";
  static String jsonAccepted = "accepted";
  static String jsonAccepted_school = "accepted_school";
  static String jsonRefused = "refused";
  static String jsonSpec = "specialization";
  static String jsonRanking = "ranking_s1";
  static String jsonEcts = "ects_number";
  static String jsonLang_lvl = "lang_lvl";
  static String jsonMissedHours = "missed_hours";
  static String jsonComment = "comment";

  static const List<String> specializationList = [
    "GSI 2A",
    "GSI 3A",
    "GSI 4A",
    "GSI 5A",
    "MRI 2A",
    "MRI 3A",
    "MRI 4A",
    "MRI 5A",
    "STI 2A",
    "STI 3A",
    "STI 4A",
    "STI 5A",
    "ENP 2A",
    "ENP 3A",
    "ENP 4A",
    "ENP 5A"
  ];
  int id;

  String name;
  Map <int, Choice> choices;
  Choice? accepted;
  List<Choice> refused = [];
  School? accepted_school;
  String specialization;
  int ranking_s1;

  int ects_number;
  String lang_lvl;
  double missed_hours;
  String comment;
  

  late int year;
  late String departement;
  Map<String, dynamic>? networkData;

  Student({required this.id, required this.name, required this.choices, required this.specialization,
    required this.ranking_s1, required this.ects_number, required this.lang_lvl, required this.missed_hours,
    required this.comment}) {
    // Fonction pour initialiser les attributs représentant l'année et le département de l'étudiant
    year_departement(specialization);
  }

  void add_student(id, name, choices, specialization, rankingS1, ectsNumber,
      langLvl, missedHours, comment) {
    this.id = id;
    this.name = name;
    for (int i = 0; i < choices.length; i++) {
      this.choices = choices[i];
    }

    this.specialization = specialization;
    this.ranking_s1 = rankingS1;
    this.ects_number = ectsNumber;
    this.lang_lvl = langLvl;
    this.missed_hours = missedHours;
    this.comment = comment;
    year_departement(specialization);
    accepted_school = null;
  }

  

  void year_departement(String specialization) {
    if (specialization.contains("2")) {
      year = 2;
    }
    else if (specialization.contains("3")) {
      year = 3;
    }
    else if (specialization.contains("4")) {
      year = 4;
    }
    else {
      year = 5;
    }

    if (specialization.contains("MRI")) {
      departement = "MRI";
    }
    else if (specialization.contains("STI")) {
      departement = "STI";
    }
    else if (specialization.contains("ENP")) {
      departement = "ENP";
    }
    else {
      departement = "GSI";
    }
  }

  void addRefusedChoice(Choice choice) {
    refused.add(choice);
  }

  void removeRefusedChoice(Choice choice) {
    refused.remove(choice);
  }

  void restoreRefusedChoice(Choice choice, int choiceKey) {
    // Restaurer un choix refusé dans la liste des choix actifs
    
    if (refused.contains(choice)) {
      refused.remove(choice);
      choices[choiceKey] = choice;
      print("CHOICE RESTORED");
    }
    print(refused);
  }

  void add_post_comment(int selectedChoice , String new_comment ) {
    if (choices.containsKey(selectedChoice)){
      this.choices[selectedChoice]!.post_comment =  new_comment;
    }
    else {
      throw Exception("The selected choice doesn't exists");
    }
  }

  String get_next_year() {
    return "$departement ${year + 1}A";
  }

  static String getNextYearFromString(String stringSpecialization){
    int year;
    String department;
    if (stringSpecialization.contains("2")) {
      year = 2;
    }
    else if (stringSpecialization.contains("3")) {
      year = 3;
    }
    else if (stringSpecialization.contains("4")) {
      year = 4;
    }
    else {
      year = 5;
    }

    if (stringSpecialization.contains("MRI")) {
      department = "MRI";
    }
    else if (stringSpecialization.contains("STI")) {
      department = "STI";
    }
    else if (stringSpecialization.contains("ENP")) {
      department = "ENP";
    }
    else {
      department = "GSI";
    }
    return "$department ${year + 1}A";
  }

  Student clone(List<School> schools){
    // Fonction nécessaire pour éviter de se retrouver à traiter un même étudiant sur deux pages différentes
    Student newStudent = Student(id : id, name : name,choices: {}, specialization:  specialization, ranking_s1:   ranking_s1,ects_number:  ects_number,lang_lvl: lang_lvl,missed_hours: missed_hours, comment: comment);
    newStudent.choices = {
      for (var entry in choices.entries) entry.key: entry.value.clone(newStudent, school: schools.where((e) => e == entry.value.school).first),
    };
    return newStudent;
  }

  double get_max_rank(){

    List<double> lst = [];
    for (var c in choices.values ){
      lst.add(c.interranking);
    }
    // Permet d'obtenir la valeur la plus élevée en terme d'interranking parmi ses choix
    double max = lst.reduce((a, b) => a > b ? a : b);

    // Une version plus simplifiée pourrait ressembler à ça
    /*
      // je récupère les valeurs du dictionnaire que je transforme en liste et à laquelle j'applique
      // la fonction reduce pour obtenir la valeur la plus élevée
      double max = choices.values.toList().reduce((a, b) => a.interranking > b.interranking ? a.interranking : b.interranking);

     */

    /*
    List<Choice> Mmax = choices.values.toList();
    Mmax.sort((a,b) => b.interranking.compareTo(a.interranking));
    print(Mmax.map((e)=> e.interranking).toList());
    */
    return max;

  }

  double get_min_rank (){

    List<double> lst = [];
    for (var c in choices.values ){
      lst.add(c.interranking);
    }
    // .reduce permet d'obtenir une seule valeur en combinant toutes les valeurs d'une liste de manière itérative
    // elle peut être utilisée pour calculer la somme de tout les éléments d'une liste
    double min = lst.reduce((a, b) => a < b ? a : b);
    return min;
  }

  // return true si l'étudiant va au second tour et false sinon
  // elle regarde si tout les voeux de l'étudiant sont présent dans refused
  bool get_second_tour (){
    for (var c in choices.values){
      if (!refused.contains(c)){
        return false;
      }
    }
    return true;
  }

  String get_graduation_level (){
    if (year == 2){
      return "bachelor";
    }
    else {
      return "master";
    }
  }

  void sortChoices(){
    List<MapEntry<int,Choice>> unsortedChoices = choices.entries.toList();
    unsortedChoices.sort((a,b) => a.key.compareTo(b.key));
    choices.clear();
    for (var choice in unsortedChoices){
      choices[choice.key] = choice.value;
    }
  }


  @override
  String toString() {
    String choicesString = choices.entries.map((entry) => '\n    Vœu ${entry.key}: ${entry.value}').join('');
    String refusedChoicesString = refused.isNotEmpty ? refused.map((choice) => '\n    Refusé: $choice').join('') : '\n    Aucun refus';
    return "${name} - Voeu accepté : ${accepted?.school.name} - Voeux refusés : ${refused.length}";
    // return 'Étudiant {\n'
    //     '  ID: $id,\n'
    //     '  Nom: $name,\n'
    //     '  Spécialisation: $specialization (Année: $year, Département: $departement),\n'
    //     '  Classement S1: $ranking_s1,\n'
    //     '  Crédits ECTS: $ects_number,\n'
    //     '  Niveau Langue: $lang_lvl,\n'
    //     '  Heures Manquées: $missed_hours,\n'
    //     '  Commentaire: "$comment",\n'
    //     '  Post-Commentaire: "${'N/A'}",\n'
    //     '  Vœux: $choicesString\n'
    //     '  Vœu Accepté: ${accepted ?? 'Aucun'}\n'
    //     '  Vœux Refusés: $refusedChoicesString\n'
    //     '}';
  }


  @override
  bool operator ==(Object other) {
    // if (identical(this, other)) return true;
    if (other is! Student) return false;
    return name == other.name && specialization == other.specialization;
  }

  Map<int, Choice> diff_interrankings() {
    Map<int, Choice> diff_dict = {};
    if (choices.isEmpty) return {};
    // Compter la fréquence de chaque interclassement
    Map<double, int> interrankFrequencies = {};
    for (var choice in choices.values) {
      interrankFrequencies.update(
        choice.interranking,
            (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    // Trouver l'interclassement le plus fréquent
    double reference_Rank;
    List<double> mostCommonRanks = interrankFrequencies.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toList();
    if (mostCommonRanks.isNotEmpty) {
      // Si des interclassements sont communs, choisir le plus fréquent
      reference_Rank = mostCommonRanks.first;
      int maxFreq = interrankFrequencies[reference_Rank]!;
      for (var rank in mostCommonRanks) {
        if (interrankFrequencies[rank]! > maxFreq) {
          reference_Rank = rank;
          maxFreq = interrankFrequencies[rank]!;
        }
      }
    } else {
      // Sinon, prendre le plus élevé
      reference_Rank = interrankFrequencies.keys.reduce((a, b) => a > b ? a : b);
    }

    // Comparer les autres vœux au reference_Rank
    for (var entry in choices.entries) {
      double currentRank = entry.value.interranking;
      if ((currentRank - reference_Rank).abs() > 1e-6) {
        diff_dict[entry.key] = entry.value;
      }
    }

    return diff_dict;
  }

  Map<int, List<Student>> ladder_interranking(
      List<Student> allStudents) {
    /// Construit une "échelle" (ladder) des étudiants qui ont obtenu une meilleure
    /// position (interclassement) que l'étudiant courant pour un même établissement,
    /// uniquement pour les vœux dont l'interclassement diffère du rang de référence.
    ///
    /// Retourne une map où la clé est la position du vœu dans `choices`
    /// et la valeur est la liste des étudiants ayant un interclassement plus favorable
    /// pour la même école.
    Map<int, List<Student>> ladder = {};
    Map<int, Choice> diffDict = diff_interrankings();
    if (diffDict.isEmpty) return {};
    for (var entry in diffDict.entries) {
      Choice c = entry.value; // Le choix problématique
      int key = entry.key; // Son index dans la liste des vœux
      ladder[key] = [];
      for (Student other in allStudents) {
        if (other.id == id) continue;
        for (Choice otherChoice in other.choices.values) {
          if (otherChoice.school.id == c.school.id &&
              otherChoice.interranking > c.interranking) {
            ladder.putIfAbsent(key, () => []);
            ladder[key]!.add(other);
          }
        }
      }
    }
    return ladder;
  }

  Map<int, List<Student>> equal_dict(List<Student> allStudent) {
    Map<int, List<Student>> equal_dict = {};
    for(var entry in choices.entries) {
      int key = entry.key;
      Choice c = entry.value;
      equal_dict[key] = [];
      for(Student other in allStudent) {
        if(other.id == id) continue;
        for(var otherChoice in other.choices.values) {
          if (otherChoice.school.id == c.school.id && (otherChoice.interranking - c.interranking).abs() < 1e-6) {
            equal_dict.putIfAbsent(key, () => []);
            equal_dict[key]!.add(other);
          }
        }
      }
    }
    return equal_dict;
  }

  bool hasNoChoiceLeft(){
    // Condition -> Aucun voeu disponible à cause de places/mauvaise formation ou choix aucun choix d'accepté
    return (refused.length == choices.length)
        || (choices.values.where(
                (e) => e.isChoiceValid() && !refused.contains(e)).isEmpty)
    ;
  }

  void initializeNetworkData(String voteType){
    if (voteType == "choiceVote"){
      networkData = {
        "choosenChoice" : -1
      };
      print(networkData);
    }
    else if (voteType == "matchVote"){
      networkData = {
        "selected" : true
      };
    }
  }

  updateNetworkData(String key, int value){
    if (networkData == null || !networkData!.containsKey(key)){
      print("${networkData == null} || ${!(networkData?.containsKey(key) ?? false)}");
      throw Exception("Not able to update networkData -> NetworkData doesn't exist or key is null");
    }
    if (networkData![key].runtimeType != value.runtimeType){
      throw Exception("Different types between initial value and new value");
    }
    networkData![key] = value;
  }

  clearNetworkData(){
    networkData = null;
  }

  Map<String, dynamic> toJson(){
    Map<String,dynamic> choicesMap = choices.map((k,v) => MapEntry(k.toString(), v.toJson()));
    List<dynamic> refusedChoiceList = refused.map((e)=> e.toJson()).toList();
    return {
      jsonId : id,
      jsonName : name,
      jsonChoices : choicesMap,
      jsonAccepted : accepted?.toJson() ?? "null",
      jsonRefused : refusedChoiceList,
      jsonSpec : specialization,
      jsonRanking : ranking_s1,
      jsonEcts : ects_number,
      jsonLang_lvl : lang_lvl,
      jsonMissedHours : missed_hours,
      jsonComment : comment,
    };
  }


  factory Student.fromJson(Map<String, dynamic> json,List<School> schools){
    Map<int, Choice> deserializedChoices = {};
    Student student = Student(
        id :json[jsonId],
        name : json[jsonName],
        choices:  deserializedChoices,
        specialization: json[jsonSpec],
        ranking_s1: json[jsonRanking],
        ects_number: json[jsonEcts],
        lang_lvl: json[jsonLang_lvl],
        missed_hours: json[jsonMissedHours],
        comment: json[jsonComment]);
    Map<String, dynamic> serializedChoices = json[jsonChoices];
    List<Choice> refusedChoices = [];
    for (var c in serializedChoices.entries){
      deserializedChoices[int.parse(c.key)] = Choice.fromJson(c.value, student,schools);
    }

    for (var c in deserializedChoices.entries){
      deserializedChoices[c.key]?.student.choices[c.key] = deserializedChoices[c.key]!;
    }

    for (var rc in json[jsonRefused]){
      refusedChoices.add(Choice.fromJson(rc, student,schools));
    }
    student.accepted = json[jsonAccepted] != "null" ? Choice.fromJson(json[jsonAccepted], student,schools) : null;
    student.refused = refusedChoices;
    return student;
  }
}
