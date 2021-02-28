import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';

import 'package:uber/model/Destino.dart';
import 'package:uber/model/Requisicao.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class PainelPassageiro extends StatefulWidget {
  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  TextEditingController _controllerDestino =
      TextEditingController(text: "Rua fiandeiras, 929");

  List<String> itensMenu = ["Configurações", "Deslogar"];

  Completer<GoogleMapController> _controller = Completer();

  CameraPosition _cameraPosition = CameraPosition(
      target: LatLng(-23.593390510783067, -46.68761592818432), zoom: 16);

  Set<Marker> _marcadores = {};
  String _idRequisicao = "";
  Position _localPassageiro;
  Map<String, dynamic> _dadosRequisicao;

  //Controles para exibição na tela
  bool _exibirCaixaEnderecoDestino = true;
  String _textoBotao = "Chamar Uber";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;

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

  _adicionarListenerLocalizacao() {
    var geolocator = GeolocatorPlatform.instance;
    var locationOptions =
        LocationOptions(accuracy: LocationAccuracy.best, distanceFilter: 10);
    geolocator
        .getPositionStream(
            desiredAccuracy: locationOptions.accuracy,
            distanceFilter: locationOptions.distanceFilter)
        .listen((Position position) {
      print("requi = " + _idRequisicao.toString());
      if (_idRequisicao != null && _idRequisicao.isNotEmpty) {
        print("Achei a requisicao");
        //Atualizar o local do passageiro
        UsuarioFirebase.atualizarDadosLocalizacao(
            _idRequisicao,
            position.latitude,
            position.longitude);


      } else if (position != null) {
        print("sumiu");
        setState(() {
          _localPassageiro = position;
        });
        _statusUberNaoChamado(); //adicionado para andar no mapa antes da req
      }
    });
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getLastKnownPosition();

    setState(() {
      if (position != null) {
        _exibirMarcadorPassageiro(position);

        _cameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 16);
        _localPassageiro = position;
        _movimentarCamera(_cameraPosition);
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcadorPassageiro(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);
      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _chamarUber() async {
    String enderecoDestino = _controllerDestino.text;
    if (enderecoDestino.isNotEmpty) {
      List<Location> listaLocations =
          await locationFromAddress(enderecoDestino);

      if (listaLocations != null && listaLocations.length > 0) {
        Location endereco = listaLocations[0];
        List<Placemark> listaEnderecos = await placemarkFromCoordinates(
            endereco.latitude, endereco.longitude);
        Placemark placemarkEndereco = listaEnderecos[0];

        Destino destino = Destino();
        destino.cidade = placemarkEndereco.administrativeArea;
        destino.cep = placemarkEndereco.postalCode;
        destino.bairro = placemarkEndereco.subLocality;
        destino.rua = placemarkEndereco.thoroughfare;
        destino.numero = placemarkEndereco.subThoroughfare;

        destino.latitude = endereco.latitude;
        destino.longitude = endereco.longitude;

        String enderecoConfirmacao;
        enderecoConfirmacao = "\n Cidade: " + destino.cidade;
        enderecoConfirmacao += "\n Rua: " + destino.rua + ", " + destino.numero;
        enderecoConfirmacao += "\n Bairro: " + destino.bairro;
        enderecoConfirmacao += "\n Cep: " + destino.cep;

        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text("Confirmação do endereço"),
                content: Text(enderecoConfirmacao),
                contentPadding: EdgeInsets.all(16),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancelar",
                        style: TextStyle(color: Colors.red),
                      )),
                  TextButton(
                      onPressed: () {
                        //Salvar requisição no firebase
                        _salvarRequisicao(destino);
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Confirmar",
                        style: TextStyle(color: Colors.green),
                      ))
                ],
              );
            });
      }
    }
  }

  _salvarRequisicao(Destino destino) async {
    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();
    passageiro.latitude = _localPassageiro.latitude;
    passageiro.longitude = _localPassageiro.longitude;

    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro = passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;

    //Salvar requisição
    db.collection("requisicoes").doc(requisicao.id).set(requisicao.toMap());

    //Salvar requisicao ativa
    Map<String, dynamic> dadosRequisicaoAtiva = {};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

    db
        .collection("requisicao_ativa")
        .doc(passageiro.idUsuario)
        .set(dadosRequisicaoAtiva);

    // chama metodo para alterar inferface para o status aguardando
      _statusAguardando();
  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado() {
    _exibirCaixaEnderecoDestino = true;
    _alterarBotaoPrincipal("Chamar Uber", Color(0xff1ebbd8), () {
      _chamarUber();
    });

    Position position = Position(
        latitude: _localPassageiro.latitude,
        longitude: _localPassageiro.longitude);
    _exibirMarcadorPassageiro(position);
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 16);
    _movimentarCamera(cameraPosition);
  }

  _statusAguardando() {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("Cancelar", Colors.red, () {
      _cancelarUber();
    });

    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];


    Position position = Position(
        latitude: passageiroLat,
        longitude: passageiroLon);
    _exibirMarcadorPassageiro(position);
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 16);
    _movimentarCamera(cameraPosition);

  }

  _statusACaminho() {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("Motorista a caminho", Colors.grey, () {
      //_cancelarUber();
    });
  }

  _cancelarUber() async {
    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    FirebaseFirestore db = FirebaseFirestore.instance;
    db
        .collection("requisicoes")
        .doc(_idRequisicao)
        .update({"status": StatusRequisicao.CANCELADA}).then((_) {
      db.collection("requisicao_ativa").doc(firebaseUser.uid).delete();
      _statusUberNaoChamado();
    });
  }

  _recuperaRequisicaoAtiva() async {
    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot documentSnapshot =
        await db.collection("requisicao_ativa").doc(firebaseUser.uid).get();

    if (documentSnapshot.data() != null) {
      Map<String, dynamic> dados = documentSnapshot.data();
      _idRequisicao = dados["id_requisicao"];
      print("peguei a req: "+_idRequisicao);
      _adicionarListenerRequisicao(_idRequisicao);
    } else {
      _statusUberNaoChamado();
    }
  }

  _adicionarListenerRequisicao(String idRequisicao) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {

        var dadosReq = snapshot.data();
        print("achei a req: "+dadosReq["id"].toString());

        Map<String, dynamic> dados = snapshot.data();

        _dadosRequisicao = dados;
        String status = dados["status"];
        _idRequisicao = dados["id"];

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

  @override
  void initState() {
    super.initState();
    //adicionar listener para requisição ativa
    _recuperaRequisicaoAtiva();

    //_recuperarUltimaLocalizacaoConhecida();
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
              // myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
            ),
            Visibility(
                visible: _exibirCaixaEnderecoDestino,
                child: Stack(
                  children: [
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
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(3),
                                color: Colors.white),
                            child: TextField(
                              readOnly: true,
                              decoration: InputDecoration(
                                  icon: Container(
                                    margin: EdgeInsets.only(left: 10),
                                    width: 10,
                                    height: 30,
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                    ),
                                  ),
                                  hintText: "Meu Local",
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.only(left: 15, top: 0)),
                            ),
                          ),
                        )),
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
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(3),
                                color: Colors.white),
                            child: TextField(
                              controller: _controllerDestino,
                              readOnly: false,
                              decoration: InputDecoration(
                                  icon: Container(
                                    margin: EdgeInsets.only(left: 10),
                                    width: 10,
                                    height: 30,
                                    child: Icon(
                                      Icons.local_taxi,
                                      color: Colors.black,
                                    ),
                                  ),
                                  hintText: "Digite o destino",
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.only(left: 15, top: 0)),
                            ),
                          ),
                        )),
                  ],
                )),
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
