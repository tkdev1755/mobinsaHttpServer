import 'package:mobinsa_web/model/Student.dart';

class School {
  //classe définissant les écoles/offres de séjours présentant toutes les informations importantes (niveau acad&miqu, langue d'ensignement,...)
  static int global_id = 0;

  /// static string to use when parsing the json, or serializing the class
  static String jsonId = "id";
  static String jsonName = "name";
  static String jsonCountry  = "country";
  static String jsonContent_type = "content_type";
  static String jsonAvailable_slots = "available_slots";
  static String jsonRemaining_slots = "remaining_slots";
  static String jsonB_slots = "b_slots";
  static String jsonM_slots = "m_slots";
  static String jsonSpecialization = "specialization";
  static String jsonGraduationLVL = "graduation_level";
  static String jsonProgram = "program";
  static String jsonUseLanguage = "use_language";
  static String jsonReq_lang_lvl = "req_lang_lvl";
  static String json_academic_lvl = "academic_lvl";
  static String jsonIsFull = "is_full";
  static String jsonIsFull_b = "is_full_b";
  static String jsonIsFull_m = "is_full_m";

  late int id;
  String name; //string définissant l'initulé de l'offre de séjour
  String country;
  String content_type;
  int available_slots; //nombre de places disponible
  late int remaining_slots; //nombres de places restantes
  int b_slots; //nombre de place disponible en bachelor
  int m_slots; //nombre de place disponible en master
  List<String> specialization; //liste des spécialisations qui peuvent postuler à cette offre de séjour
  String graduation_level;
  String program; // Formation concernée par l'offre de séjour
  String use_langage; // langue d'enseignement
  String req_lang_level; //niveau minimum de langue souhaité
  String academic_level; //niveau académque souhaité
  bool is_full = false;
  bool is_full_b = false;
  bool is_full_m = false;

  School({required this.name,required this.country,required this.content_type,required this.available_slots,
    required this.b_slots,required this.m_slots,required this.specialization,required this.graduation_level,
    required this.program,required this.use_langage, required this.req_lang_level,
    required this.academic_level, int? initialID, int? overrideRemainingPlaces}) {
    if (initialID !=null){
      id = initialID;
    }
    else{
    id = global_id;
    global_id++;
    }
    if (overrideRemainingPlaces != null){
      remaining_slots = overrideRemainingPlaces;
    }
    else{
      remaining_slots = available_slots;
    }
  }

  static void setGlobalID(int globalID){
    global_id = globalID;
  }

  void setId(int id){
    this.id = id;
  }

  void reduce_slots(Student s) {
    //réduire le nombre de places d'une offre de séjour si on affecté une mobilité à un étudiant
    if (remaining_slots > 0) {
      remaining_slots--;
      // this.available_slots--;
      if (s.year > 2) {
        m_slots--;
        //print("SLOT SUCCESSFULLY REMOVED MASTER");
        if (m_slots == 0) is_full_m = true;
      }
      else if (s.year == 2) {
        b_slots--;
        //print("SLOT SUCCESSFULLY REMOVED LICENCE");
        if (b_slots == 0) is_full_b = true;
      }
    }
    if (remaining_slots == 0) {
      is_full = true;
    }
  }

  void add_slots(Student s) {
    //augmenter le nombre de places si on décide d'enlever une mobilité à un élève
    if(remaining_slots < available_slots){
      remaining_slots++;
      if (s.year > 2) m_slots++;
      if (s.year == 2) b_slots++;
    }
    else{
      print("NO MORE SLOTS AVAILABLE");
    }
  }

  int getPlacesBySpecialization(String specialization){
    if(specialization == "master"){
      return m_slots;
    }
    else if (specialization == "bachelor") {
      return b_slots;
    }
    else {
      return -1;
    }
  }

  bool accepted(Student s) {
    //affectation d'une offre de séjour à un élève
    //print("s.year : ${s.year}");
    //print("this.b_slots : ${b_slots}");
    //print("this.specialization : ${specialization}");
    //print("s.get_next_year() : ${s.get_next_year()}");
    //Les 2A ne pourront quand même pas prendre de formation en master !
    if (s.year == 2 && this.b_slots > 0 ) {
      //print("ACCEPTED SCHOOL LICENCE");
      reduce_slots(s);
      return true;
    }
    else if (s.year > 2 && this.m_slots > 0 ) {
      //print("ACCEPTED SCHOOL MASTER");
      reduce_slots(s);
      return true;
    }
    return false;
  }
  @override
  String toString() {
    return "Ecole : $name - $country - $specialization";
  }

  String getSpecializations(){
    return specialization.toString().replaceAll("[", "").replaceAll("]", "");
  }
  School clone(){
    return School(name: name,country:  country, content_type:  content_type, available_slots: available_slots, b_slots:  b_slots, m_slots:  m_slots, specialization: specialization, graduation_level: graduation_level,program:  program, use_langage: use_langage, req_lang_level: req_lang_level, academic_level: academic_level, initialID: id, overrideRemainingPlaces: remaining_slots);
  }

  (bool,String) isCoherent(){
    List<(bool,String)> conditions = [
      (available_slots == (b_slots+m_slots)
          ||
          (available_slots == b_slots
              && available_slots == m_slots
              && (specialization.contains("ENP 2A"))
          ), "Places incohérentes"), // takes care of the fact that the ENP choices don't have a set number of places for bachelor and master students as they are in the same ballot for their mobility
      (specialization.isNotEmpty, "Aucune spécialisation n'as été detectée"),
    ];
    return (conditions.where((e) => !e.$1).isEmpty, "${conditions.where((e) => !e.$1).firstOrNull?.$2}");
  }


  Map<String,dynamic> toJson(){
    return {
      jsonId : id,
      jsonName : name,
      jsonCountry : country,
      jsonContent_type : content_type,
      jsonAvailable_slots : available_slots,
      jsonRemaining_slots : remaining_slots,
      jsonB_slots : b_slots,
      jsonM_slots : m_slots,
      jsonSpecialization : specialization,
      jsonGraduationLVL : graduation_level,
      jsonProgram : program,
      jsonUseLanguage : use_langage,
      jsonReq_lang_lvl : req_lang_level,
      json_academic_lvl : academic_level,
      jsonIsFull : is_full,
      jsonIsFull_b : is_full_b,
      jsonIsFull_m : is_full_m,
    };
  }

  factory School.fromJson(Map<String, dynamic> json) {
    School school = School(
      name: json[jsonName],                          // name
      country: json[jsonCountry],                       // country
      content_type: json[jsonContent_type],                  // content_type
      available_slots: json[jsonAvailable_slots],               // available_slots
      b_slots: json[jsonB_slots],                       // b_slots
      m_slots: json[jsonM_slots],                       // m_slots
      specialization : List<String>.from(json[jsonSpecialization]), // specialization
      graduation_level: json[jsonGraduationLVL],                 // graduation_level
      program: json[jsonProgram],
      use_langage: json[jsonUseLanguage],                   // use_langage
      req_lang_level: json[jsonReq_lang_lvl],                  // req_lang_level
      academic_level: json[json_academic_lvl],
      initialID: json[jsonId], // academic_level,
      overrideRemainingPlaces: json[jsonRemaining_slots],
    );
    school.is_full = json[jsonIsFull];
    school.is_full_b = json[jsonIsFull_b];
    school.is_full_m = json[jsonIsFull_m];
    return school;
  }

  @override
  bool operator ==(Object other) {
    // if (identical(this, other)) return true;
    if (other is! School) return false;
    return id == other.id;
  }

}
