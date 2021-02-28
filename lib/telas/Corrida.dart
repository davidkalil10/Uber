import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {
  String idRequisicao;

  Corrida(this.idRequisicao);

  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {
  Completer<GoogleMapController> _controller = Completer();

  CameraPosition _cameraPosition = CameraPosition(
      target: LatLng(-23.593390510783067, -46.68761592818432), zoom: 16);

  Set<Marker> _marcadores = {};
  Map<String, dynamic> _dadosRequisicao;
  Position _localMotorista;

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;

  _adicionarListenerLocalizacao() {
    var geolocator = GeolocatorPlatform.instance;
    var locationOptions =
    LocationOptions(accuracy: LocationAccuracy.best, distanceFilter: 10);
    geolocator
        .getPositionStream(
        desiredAccuracy: locationOptions.accuracy,
        distanceFilter: locationOptions.distanceFilter)
        .listen((Position position) {
      _exibirMarcadorMotorista(position);
      _cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 16);
      //_movimentarCamera(_cameraPosition);
      _localMotorista = position;
    });
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getLastKnownPosition();

    setState(() {
      if (position != null) {
        _exibirMarcadorMotorista(position);
        _cameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 16);

        //_movimentarCamera(_cameraPosition);
        _localMotorista = position;
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcadorMotorista(Position local) async {
    double pixelRatio = MediaQuery
        .of(context)
        .devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorMotorista = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);
      setState(() {
        _marcadores.add(marcadorMotorista);
      });
    });
  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot =
    await db.collection("requisicoes").doc(idRequisicao).get();
    _dadosRequisicao = documentSnapshot.data();
    _adicionarListenerRequisicao();
  }

  _adicionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];
    await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        Map<String, dynamic> dados = snapshot.data();
        String status = dados["status"];

        switch (status) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM:
            break;
          case StatusRequisicao.FINALIZADA:
            break;
        }
      }
    });
  }

  _statusAguardando() {
    _alterarBotaoPrincipal("Aceitar Corrida", Color(0xff1ebbd8), () {
      _aceitarCorrida();
    });
  }

  _statusACaminho() {
    _alterarBotaoPrincipal("A caminho do passageiro", Colors.grey, null);

    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];

   // print("pass: " +latitudePassageiro.toString() + "-"+longitudePassageiro.toString());
   // print("moto: " +latitudeMotorista.toString() + "-"+longitudeMotorista.toString());


    //Exibir dois marcadores
    _exibirDoisMarcadores(
        LatLng(latitudeMotorista, longitudeMotorista),
        LatLng(latitudePassageiro, longitudePassageiro));

    //latitude southwest tem que ser <= north
    var sLat, sLon, nLat,nLon;

    if(latitudeMotorista<=latitudePassageiro){
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    }else {
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }
    if(longitudeMotorista<=longitudePassageiro){
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    }else {
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }
    _movimentarCameraBounds(
      LatLngBounds(
          southwest: LatLng(sLat,sLon),
          northeast: LatLng(nLat,nLon))
    );

  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(
      CameraUpdate.newLatLngBounds(
          latLngBounds,
          100)
    );
  }



  _exibirDoisMarcadores(LatLng latLngMoto, LatLng latLngPass) {

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> _listaMarcadores = {};

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorMotorista = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(latLngMoto.latitude, latLngMoto.longitude),
          infoWindow: InfoWindow(title: "Motorista"),
          icon: icone);
      _listaMarcadores.add(marcadorMotorista);

    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(latLngPass.latitude, latLngPass.longitude),
          infoWindow: InfoWindow(title: "Passageiro"),
          icon: icone);
      _listaMarcadores.add(marcadorPassageiro);
    });

    setState(() {
      _marcadores = _listaMarcadores;

    });








  }

  _aceitarCorrida() async {
    //Recuperar dados do motorista
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];

    db.collection("requisicoes").doc(idRequisicao).update({
      "motorista": motorista.toMap(),
      "status": StatusRequisicao.A_CAMINHO
    }).then((_) {
      //atualiza requisicao ativa
      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db
          .collection("requisicao_ativa")
          .doc(idPassageiro)
          .update({"status": StatusRequisicao.A_CAMINHO});
      //Salvar requisicao ativa para motorista
      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista").doc(idMotorista).set({
        "id_requisicao": idRequisicao,
        "id_usuario": idMotorista,
        "status": StatusRequisicao.A_CAMINHO
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();
    //recuperar requisicao e
    //adicionar listener para mudança de staus
    _recuperarRequisicao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel Corrida"),
      ),
      body: Container(
        child: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _cameraPosition,
              onMapCreated: _onMapCreated,
              // myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : EdgeInsets.all(10),
                child: ElevatedButton(
                  child: Text(
                    _textoBotao,
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                      primary: _corBotao,
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16)),
                  onPressed: _funcaoBotao,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}