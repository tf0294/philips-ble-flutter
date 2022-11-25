import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class BleScreen extends StatefulWidget {
  const BleScreen({Key? key}) : super(key: key);

  @override
  State<BleScreen> createState() => _BleScreen();
}

class _BleScreen extends State<BleScreen> {
  void initState() {
    super.initState();
  }

  Widget build(BuildContext context) {
      return MaterialApp(
        home: StreamBuilder<BluetoothState>(
            stream: FlutterBluePlus.instance.state,
            initialData: BluetoothState.unknown,
            builder: (c, snapshot) {
              final state = snapshot.data;
              if (state == BluetoothState.on || state == BluetoothState.unknown) {
                return BluetoothOnScreen();
              }
              return BluetoothOffScreen(state: state);
            }),
      );
  }
}

class BluetoothOnScreen extends StatefulWidget {
  const BluetoothOnScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothOnScreen> createState() => _BluetoothOnScreen();
}

class _BluetoothOnScreen extends State<BluetoothOnScreen> {
  bool isConected = false;
  bool isPower = true;
  Color _color = Colors.yellowAccent;
  double _rangeValue = 200;
  BluetoothDevice? _scannedDevice = null;
  BluetoothCharacteristic? _powerCharacteristic = null;
  BluetoothCharacteristic? _colorCharacteristic = null;
  BluetoothCharacteristic? _brightnessCharacteristic = null;

  _startScan() async {
    return FlutterBluePlus.instance.isOn.then((bool isOn) {
      if (isOn) {
        FlutterBluePlus.instance.isScanning.first.then((bool isScanning) async {
          if (!isScanning) {
           var stream =  await FlutterBluePlus.instance.scan(timeout: const Duration(seconds: 4));
            stream.listen((ScanResult result) async {
              if(result.device.name == "Hue color lamp") {
                try {
                  await _connect(result.device);
                  setState(() {
                    this.isConected = true;
                    this._scannedDevice = result.device;
                  });
                } catch (error) {
                  print(error);
                }
              }
            }).onDone(() async {
              _stopScan();
            });
          }
        });
      }
    });
  }

  // http://www.crus.in/codes/ble.html
  _discoverServices(BluetoothDevice device) async{
    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) {
      if (service.uuid.toString().compareTo("932c32bd-0000-47a2-835a-a8d455b859dd") == 0) {
        service.characteristics.forEach((characteristic) {
          // power on/off
          if (characteristic.uuid.toString().compareTo("932c32bd-0002-47a2-835a-a8d455b859dd") == 0) {
            setState((){
              _powerCharacteristic = characteristic;
            });

          // color
          } else if(characteristic.uuid.toString().compareTo("932c32bd-0005-47a2-835a-a8d455b859dd") == 0) {
            setState((){
              _colorCharacteristic = characteristic;
            });

          } else if(characteristic.uuid.toString().compareTo("932c32bd-0003-47a2-835a-a8d455b859dd") == 0) {
            setState((){
              _brightnessCharacteristic = characteristic;
            });

          }
        });
      }
    });
  }

  _writePowerCharacteristic(BluetoothCharacteristic characteristic) async {
    List<int> _getValue() {
      return [(this.isPower) ? 1 : 0];
    }
    try {
      print("power change start.");
      await characteristic.write(Uint8List.fromList(_getValue()), withoutResponse: false);
      print("power change end.");
      print(this.isPower.toString());
    } on Exception catch (e) {
      print(e.toString());
    }
  }

  _writeColorCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      print("color change start.");
      print([1, _color.red, _color.green, _color.blue]);
      var colors = _convertHueColorCode(_color.red, _color.green, _color.blue);
      print(colors.toString());
      await characteristic.write(Uint8List.fromList([1, colors[0], colors[1], colors[2]]), withoutResponse: false);
      print("color change end.");
    } on Exception catch (e) {
      print(e.toString());
    }
  }

  _writeBrightnessCharacteristic(BluetoothCharacteristic characteristic) async {
    List<int> _getValue() {
      return [this._rangeValue.toInt()];
    }
    try {
      print("brightness start.");
      await characteristic.write(Uint8List.fromList(_getValue()), withoutResponse: false);
      print("brightness end.");
      print(this._rangeValue.toInt().toString());
    } on Exception catch (e) {
      print(e.toString());
    }
  }

  _convertHueColorCode(red, blue, green) {
    // Sets color by converting RGB colors to an internal color code using a formula
    // of dubious accuracy:
    // min(1, round(color[i]/sum(color)*255))
    var scale = 0xff;
    var total = red + blue + green;
    print("total:"+total.toString());
    var adjusted_red = red/total * scale;
    var adjusted_blue = blue/total * scale;
    var adjusted_green = green/total * scale;
    return [adjusted_red.round(), adjusted_blue.round(), adjusted_green.round()];
  }

  _connect(BluetoothDevice device) async {
    try {
      bool isConnect = true;
      await device.connect().timeout(const Duration(seconds: 5),
          onTimeout: () async {
            print("Bluetooth connect timeout.");
            isConnect = false;
            await device.disconnect();
          }).then((data) {
        if (isConnect) {
          _discoverServices(device);
          print("Bluetooth connect success.");
        }
      });
    } on Exception catch (e) {
      print('Bluetooth connect error:$e');
    }
  }

  _stopScan() async {
    await FlutterBluePlus.instance.stopScan();
  }

  _disconnect() async {
    if(this._scannedDevice == null) {
      return;
    }
    await this._scannedDevice?.disconnect();
    setState(() {
      this.isConected = false;
    });
  }

  _getPowerSampleIcon() {
    if(this.isPower) {
      return Icon(Icons.lightbulb_circle_rounded, color: Colors.white, size: 56);
    } else {
      return Icon(Icons.lightbulb_circle_rounded, color: Colors.grey, size: 56);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white12,
      //floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Column(
        //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _colorSampleArea(),
          _brightnessArea(),
          _powerArea(),
          _bottomArea(),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text("Select a Color"),
              content: Container(
                width: double.infinity,
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ColorPicker(
                  pickerColor: _color,
                  onColorChanged: (Color color) {
                    if (this._colorCharacteristic == null) {
                      return;
                    }
                    setState(() {
                      _color = color;
                      _writeColorCharacteristic(this._colorCharacteristic!);
                    });
                    },
                  pickerAreaHeightPercent: 0.9,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hueWheel,
                ),
            ),
            actions: <Widget>[
              ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel")
              ),
            ],
        )
    );
  }

  Widget _colorSampleArea() {
    return Container(
      width: double.infinity,
      height: (MediaQuery.of(context).size.height / 100) * 17,
      color: (this.isPower) ? this._color : Color.fromRGBO(56, 85, 114, 1),
      child: Center(
        child: _getPowerSampleIcon(),
      ),
    );
  }

  Widget _brightnessArea() {
    return Container(
      width: double.infinity,
      height: (MediaQuery.of(context).size.height / 100) * 22,
      alignment: Alignment.center,
      color: Color.fromRGBO(56, 85, 114, 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            child: Icon(Icons.light_mode_outlined, color: Colors.white,size: 20),
            alignment: Alignment.centerRight,
            width: 10.0,
          ),
          Container(
            width: 300,
            child: Slider(
            label: '${this._rangeValue}',
            value: this._rangeValue,
            min: 1,
            max: 254,
            activeColor: Colors.white,
            inactiveColor: Colors.grey,
            onChanged: (value) {
              setState(() {
                this._rangeValue = value.round().toDouble();
                print(this._rangeValue.toString());
                _writeBrightnessCharacteristic(this._brightnessCharacteristic!);
              });
            },
          )
          ),
          Container(
            child: Icon(Icons.light_mode, color: Colors.white,size: 20),
            width: 10.0,
            alignment: Alignment.centerLeft,
          ),
        ],
      ),
    );
  }

  Widget _powerArea() {
    return Container(
        width: double.infinity,
        height: (MediaQuery.of(context).size.height / 100) * 40,
        color: Color.fromRGBO(56, 85, 114, 1),
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (this.isPower) ? Colors.white : Colors.white24,
          ),
          child: IconButton(
          onPressed: () {
            if(this._powerCharacteristic == null) {
              return;
            }
            setState(() {
              this.isPower = !this.isPower;
              _writePowerCharacteristic(this._powerCharacteristic!);
            });
          },
          icon: Icon(Icons.power_settings_new),
          iconSize: 45.0,
          color: (this.isPower) ? Colors.blue : Colors.grey,
      ),
    ));
  }

  Widget _bottomArea() {
    return Container(
      width: double.infinity,
      height: (MediaQuery.of(context).size.height / 100) * 8,
      alignment: Alignment.topLeft,
      color: Color.fromRGBO(14, 43, 71, 1),
      child: Padding(
        padding: EdgeInsets.all(5.0),
        child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.only(top:1.0, left: 10.0, right: 30.0),
            onPressed: () {
              if(this.isConected) {
                _disconnect();
              } else {
                _startScan();
              }
            },
            icon: (this.isConected) ? Icon(Icons.bluetooth_connected, size: 30, color: Colors.blue) : Icon(Icons.bluetooth_disabled, size: 30, color: Colors.white),
          ),
          IconButton(
            padding: EdgeInsets.only(top:1.0, left: 10.0, right: 30.0),
              onPressed: () {
                _showPicker(context);
              },
              icon: Icon(Icons.color_lens_outlined, size: 30, color: Colors.white),
          )
        ],
      ),
      ),
    );
  }

}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, required this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(14, 43, 71, 1),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.blueAccent,
            ),
            Text(
              'Bluetoothを${state != null ? "ONにしてください" : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subtitle2
                  ?.copyWith(color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }
}