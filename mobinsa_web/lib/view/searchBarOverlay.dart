import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:fuzzy/data/result.dart';
import 'package:fuzzy/fuzzy.dart';

import '../../model/Student.dart';
import 'package:diacritic/diacritic.dart';

class SearchService {

  List<Student> searchStudents(String query, List<Student> students) {
    if (query.trim().isEmpty) return [];

    // Configuration du moteur Fuzzy
    final fuse = Fuzzy<Student>(
      students,
      options: FuzzyOptions(

        keys: [
          WeightedKey(
            name: 'name',
            getter: (Student s) => s.name,
            weight: 1.0,
          ),
        ],
        threshold: 0.3,
      ),
    );

    final result = fuse.search(query);
    return result.map((r) => r.item).toList();
  }
}


class StudentSearchBar extends StatefulWidget {
  final List<Student> students;
  final Function onSelect;
  const StudentSearchBar({super.key, required this.students, required this.onSelect});

  @override
  State<StudentSearchBar> createState() => _StudentSearchBarState();
}

class _StudentSearchBarState extends State<StudentSearchBar> {
  final TextEditingController _controller = TextEditingController();

  Future<List<Student>> _search(String query) async {
    List<Student> result = SearchService().searchStudents(query, widget.students);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        child: TypeAheadField<Student>(
          suggestionsCallback: _search,
          builder: (context, controller, focusNode) {
            return TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)
                  ),
                  labelText: 'Rechercher un étudiant',
                )
            );
          },
          itemBuilder: (context, suggestion) {
            return ListTile(
              title: Text(suggestion.name),
            );
          },
          onSelected: (suggestion) {
            print("Selected student : $suggestion");
            int index = widget.students.indexOf(suggestion);
            print("Index of  this student is $suggestion");
            widget.onSelect(suggestion.id);
            _controller.text = suggestion.name;
          },
          hideOnEmpty: true,
          hideOnLoading: true,
          hideOnError: true,
          animationDuration: const Duration(milliseconds: 150),
        ),
      ),
    );
  }
}
