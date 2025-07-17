import 'package:flutter/material.dart';

// LIGHT AND DARK MODE THEMES
ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  fontFamily: 'Nunito',
  scaffoldBackgroundColor: Colors.white,
  cardColor: const Color.fromARGB(255, 218, 218, 219),
  highlightColor: Colors.grey.shade500,
  
 
  indicatorColor: const Color.fromARGB(255, 77, 76, 76),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black),
  ),
);

ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Nunito',
  scaffoldBackgroundColor: const Color.fromARGB(255, 24, 24, 26),
  cardColor: const Color.fromARGB(51, 195, 195, 197),
    highlightColor: Colors.grey.shade300,

  indicatorColor: const Color.fromARGB(255, 180, 178, 178),
  textTheme: const TextTheme(
    bodySmall: TextStyle(color: Colors.white),
  ),
);
