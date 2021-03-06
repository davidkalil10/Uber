import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uber/model/Usuario.dart';

class UsuarioFirebase {
  static Future<User> getUsuarioAtual() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    return await auth.currentUser;
  }

  static Future<Usuario> getDadosUsuarioLogado() async {
    User firebaseUser = await getUsuarioAtual();
    String idUsuario = firebaseUser.uid;

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot snapshot =
        await db.collection("usuarios").doc(idUsuario).get();

    Map<String, dynamic> dados = snapshot.data();
    String tipoUsuario = dados["tipoUsuario"];
    String email = dados["email"];
    String nome = dados["nome"];

    Usuario usuario = Usuario();
    usuario.idUsuario = idUsuario;
    usuario.tipoUsuario = tipoUsuario;
    usuario.nome = nome;
    usuario.email = email;

    return usuario;
  }

  static atualizarDadosLocalizacao(String idRequisicao, double lat, double lon) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    Usuario passageiro = await getDadosUsuarioLogado();
    passageiro.latitude = lat;
    passageiro.longitude = lon;
    print("Checando tipo usuario: " + passageiro.tipoUsuario);

    if (passageiro.tipoUsuario == "Passageiro") {
      db
          .collection("requisicoes")
          .doc(idRequisicao)
          .update({"passageiro": passageiro.toMap()});
    }else if(passageiro.tipoUsuario == "Motorista"){
      db
          .collection("requisicoes")
          .doc(idRequisicao)
          .update({"motorista": passageiro.toMap()});
    }


  }
}
