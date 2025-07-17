import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  final TextEditingController searchController;
  final void Function(String) searchFunction;
  final Future<void> Function() loadRecordings;

  const SearchField(
      {super.key,
      required this.searchController,
      required this.searchFunction,
      required this.loadRecordings});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: searchController,
      onChanged: searchFunction,
      // onSubmitted: searchFunction,
      decoration: InputDecoration(
        suffixIcon: IconButton(
            onPressed: ()async {
              searchController.clear();
              await loadRecordings();
              searchFunction('');
            },
            icon: Icon(Icons.restore_outlined,
                color: Theme.of(context).indicatorColor)),
       
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).highlightColor,
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).highlightColor,
            width: 2,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).highlightColor,
          ),
        ),
        hintText: 'Search',
        hintStyle: TextStyle(
            color: Theme.of(context).highlightColor,
        ),
      ),
    );
  }
}
