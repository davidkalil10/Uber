import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';

class PainelPassageiro extends StatefulWidget {
  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  List<String> itensMenu = ["Configurações", "Deslogar"];

  Completer<GoogleMapController> _controller = Completer();

  CameraPosition _cameraPosition = CameraPosition(
      target: LatLng(-23.593390510783067, -46.68761592818432), zoom: 16);

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  _deslogarUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao(){
    var geolocator = GeolocatorPlatform.instance;
    var locationOptions = LocationOptions(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10
    );
    geolocator.getPositionStream(desiredAccuracy: locationOptions.accuracy, distanceFilter: locationOptions.distanceFilter).listen((Position position) {
      _cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 16);
      _movimentarCamera(_cameraPosition);
    });
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getLastKnownPosition();

    setState(() {
      if (position != null) {
        _cameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 16);
      _movimentarCamera(_cameraPosition);
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition)async{
    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  @override
  void initState() {
    super.initState();
    _recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel Passageiro"),
        actions: [
          PopupMenuButton<String>(
              onSelected: _escolhaMenuItem,
              itemBuilder: (context) {
                return itensMenu.map((String item) {
                  return PopupMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList();
              }),
        ],
      ),
      body: Container(
        child: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _cameraPosition,
              onMapCreated: _onMapCreated,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            ),
            Positioned(
              top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color:Colors.grey ),
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.white
                    ),
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        icon: Container(
                          margin: EdgeInsets.only(left: 10),
                          width: 10,
                          height: 30,
                          child: Icon(Icons.location_on,color: Colors.green,),
                        ),
                        hintText: "Meu Local",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(left: 15,top: 0)
                      ),
                    ),
                  ),
                )
            ),
            Positioned(
                top: 55,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        border: Border.all(color:Colors.grey ),
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white
                    ),
                    child: TextField(
                      readOnly: false,
                      decoration: InputDecoration(
                          icon: Container(
                            margin: EdgeInsets.only(left: 10),
                            width: 10,
                            height: 30,
                            child: Icon(Icons.local_taxi,color: Colors.black,),
                          ),
                          hintText: "Digite o destino",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(left: 15,top: 0)
                      ),
                    ),
                  ),
                )
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ?EdgeInsets.fromLTRB(20, 10, 20, 25)
                    :EdgeInsets.all(10),
                child: ElevatedButton(
                  child: Text(
                    "Chamar Uber",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                      primary: Color(0xff1ebbd8),
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16)),
                  onPressed: () {

                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
