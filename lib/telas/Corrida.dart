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
  String _idRequisicao;
  Position _localMotorista;
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;


  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;
  String _mensagemStatus = "";

  _adicionarListenerLocalizacao() {
    var geolocator = GeolocatorPlatform.instance;
    var locationOptions =
    LocationOptions(accuracy: LocationAccuracy.best, distanceFilter: 10);
    geolocator
        .getPositionStream(
        desiredAccuracy: locationOptions.accuracy,
        distanceFilter: locationOptions.distanceFilter)
        .listen((Position position) {
        print("requix = " + _idRequisicao.toString());
        print("minhpos = " + _localMotorista.toString());
        _localMotorista = position;
        //_recuperarUltimaLocalizacaoConhecida();

       if (position!= null){
         if (_idRequisicao != null && _idRequisicao.isNotEmpty) {
           print("Achei a requisicao");


           if(_statusRequisicao != StatusRequisicao.AGUARDANDO){
             //Atualizar o local do passageiro
             UsuarioFirebase.atualizarDadosLocalizacao(
                 _idRequisicao,
                 position.latitude,
                 position.longitude);
             _localMotorista = position;
           }

           setState(() {
             _localMotorista = position;
             if(_statusRequisicao == StatusRequisicao.AGUARDANDO){
               _statusAguardando();
             }

           });

         } else{
           _recuperarUltimaLocalizacaoConhecida();
         }

       }else{
         _recuperarUltimaLocalizacaoConhecida();
       }

    });
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getLastKnownPosition();
    print("minhpos2 = " + position.toString());
    if (position != null) {
      //Atualizar localização em tempo real do motorista
      print("minhpos2 = " + position.toString());
      setState(() {
        _localMotorista = position;
      });


    }
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {
    double pixelRatio = MediaQuery
        .of(context)
        .devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        icone)
        .then((BitmapDescriptor bitmapDescriptor) {
      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: infoWindow),
          icon: bitmapDescriptor);
      setState(() {
        _marcadores.add(marcador);
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




  }

  _adicionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
   // String idRequisicao = _dadosRequisicao["id"];
    await db
        .collection("requisicoes")
        .doc(_idRequisicao)
        .snapshots()
        .listen((snapshot) {

      if (snapshot.data() != null) {

        _dadosRequisicao = snapshot.data();

        Map<String, dynamic> dados = snapshot.data();
        _statusRequisicao = dados["status"];
        print("consegui consultar: "+_statusRequisicao);

        switch (_statusRequisicao) {
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

   // double motoristaLat = _dadosRequisicao["motorista"]["latitude"];
  //  double motoristaLon = _dadosRequisicao["motorista"]["longitude"];

   // double motoristaLat = -23.5959;
  //  double motoristaLon = -46.6872783;




    Position position = Position(
      latitude: _localMotorista.latitude,
      longitude:_localMotorista.longitude
    );
    _exibirMarcador(
      position,
        "imagens/motorista.png",
        "Motorista"
    );
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 16);

    _movimentarCamera(cameraPosition);
  }

  _statusACaminho() {
    _mensagemStatus = "A caminho do passageiro";

    _alterarBotaoPrincipal("Iniciar Corrida", Color(0xff1ebbd8), (){
      _iniciarCorrida();
    });


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

  _iniciarCorrida(){

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
   // motorista.latitude = _dadosRequisicao["motorista"]["latitude"];
   // motorista.longitude = _dadosRequisicao["motorista"]["longitude"];

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

    _idRequisicao = widget.idRequisicao;
    print("recebi a req "+_idRequisicao.toString());
    //adicionar listener para mudanças na requisição
    _adicionarListenerRequisicao();

    //_recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel Corrida - " + _mensagemStatus),
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