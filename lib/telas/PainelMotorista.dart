import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class PainelMotorista extends StatefulWidget {
  @override
  _PainelMotoristaState createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {
  List<String> itensMenu = ["Configurações", "Deslogar"];

  final _controller = StreamController<QuerySnapshot>.broadcast();
  FirebaseFirestore db = FirebaseFirestore.instance;

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

  Stream<QuerySnapshot> _adicionarListenerRequisicoes() {
    final stream = db
        .collection("requisicoes")
        .where("status", isEqualTo: StatusRequisicao.AGUARDANDO)
        .snapshots();

    stream.listen((dados) {
      _controller.add(dados);
    });
  }

  _recuperarRequisicaoAtivaMotorista() async {
    //Recupera dados do usuario logado
    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();

    //Recupera requisicao ativa
    DocumentSnapshot documentSnapshot = await db
        .collection("requisicao_ativa_motorista")
        .doc(firebaseUser.uid)
        .get();

    var dadosRequisicao = documentSnapshot.data();
    if (dadosRequisicao == null) {
      //Listar requisicoes disponíveis para o motorista
      _adicionarListenerRequisicoes();
    } else {
      String idRequisicao = dadosRequisicao["id_requisicao"];
      Navigator.pushReplacementNamed(context, "/corrida", arguments: idRequisicao);
    }
  }

  @override
  void initState() {
    super.initState();
    //Recupera requisicao ativa para ver se motorista esta atendendo alguma
    //envia motorista para a tela de corrida

    _recuperarRequisicaoAtivaMotorista();
  }

  @override
  Widget build(BuildContext context) {
    var mensagemCarregando = Center(
      child: Column(
        children: [Text("Carregando requisições"), CircularProgressIndicator()],
      ),
    );

    var mensagemNaotemDados = Center(
      child: Text(
        "Você não tem nenhuma requisição :/",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel Motorista"),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.stream,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return mensagemCarregando;
              break;
            case ConnectionState.active:
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Text("Erro ao carregar os dados!");
              } else {
                QuerySnapshot querySnapshot = snapshot.data;
                if (querySnapshot.docs.length == 0) {
                  return mensagemNaotemDados;
                } else {
                  return ListView.separated(
                    itemCount: querySnapshot.docs.length,
                    separatorBuilder: (context, indice) => Divider(
                      height: 2,
                      color: Colors.grey,
                    ),
                    itemBuilder: (context, indice) {
                      List<DocumentSnapshot> requisicoes =
                          querySnapshot.docs.toList();
                      DocumentSnapshot item = requisicoes[indice];

                      String idRequisicao = item["id"];
                      String nomePassageiro = item["passageiro"]["nome"];
                      String rua = item["destino"]["rua"];
                      String numero = item["destino"]["numero"];

                      return ListTile(
                        title: Text(nomePassageiro),
                        subtitle: Text("Destino: $rua, $numero"),
                        onTap: () {
                          Navigator.pushNamed(context, "/corrida",
                              arguments: idRequisicao);
                        },
                      );
                    },
                  );
                }
              }
              break;
          }
        },
      ),
    );
  }
}
