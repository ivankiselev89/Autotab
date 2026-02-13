import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Menu'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Logic for starting recording goes here
          },
          child: Text('Start Recording'),
        ),
      ),
    );
  }
}