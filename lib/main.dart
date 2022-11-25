import 'package:flutter/material.dart';
import 'package:ainenne/ble.dart';

void main() =>  runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const MyStatefulWidget(),
    );
  }
}

class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({Key? key}) : super(key: key);

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {

  @override
  //https://riscait.medium.com/display-an-image-icon-in-the-flutters-appbar-leading-c3fbed2ae766
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("ainenne"),
          leading: _buildProfileIconButton(),
          backgroundColor: Color.fromRGBO(14, 43, 71, 1),
        ),
        body: Container(
          padding: EdgeInsets.only(left: 0.0, right: 0.0),
          margin: EdgeInsets.only(top: 0.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black12,
              width: 0.0,
            )
          ),
          child: BleScreen(),
        ),
    );
  }

  Widget _buildProfileIconButton() {
    const iconSize = 32.0;
    return IconButton(
      icon: Icon(Icons.account_circle, size: iconSize),
      onPressed: null,
    );
  }
}
