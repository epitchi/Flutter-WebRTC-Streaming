import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:messagepack/messagepack.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC Streaming',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter WebRTC Streaming'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool offer = false;
  late RTCPeerConnection peerConnection;
  late MediaStream localStream;
  final localRenderer = new RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  final sdpController = TextEditingController();
  @override
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderers();
    _createPeerConnection().then((pc) {
      peerConnection = pc;
    });
    super.initState();
  }

  initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"}
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": []
    };

    localStream = await getUserMedia();

   RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(localStream);

    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        final packer = Packer();
        packer.packString(e.candidate);
        packer.packString(e.sdpMid.toString());
        packer.packString(e.sdpMlineIndex.toString());
        final bytes = packer.takeBytes();
        print("Message Pack convert below");
        print(bytes);

        print("Jso code candidate");
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        }));
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream' + stream.id);
      remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {'facingMode': 'user'}
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    localRenderer.srcObject = stream;

    return stream;
  }

  void createOffer() async {
    RTCSessionDescription description =
        await peerConnection.createOffer({'offerToReiceveVideo': 1});
    var session = parse(description.sdp.toString());
    print(json.encode(session));
    offer = true;

    peerConnection.setLocalDescription(description);
  }

  void createAnswer() async {
    RTCSessionDescription description =
        await peerConnection.createAnswer({'offerToReiceveVideo': 1});
    var session = parse(description.sdp.toString());
    print(json.encode(session));

    peerConnection.setLocalDescription(description);
  }

  void setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');

    String sdp = write(session, null);

    RTCSessionDescription description =
        new RTCSessionDescription(sdp, offer ? 'answer' : 'offer');

    print(description.toMap());

    await peerConnection.setRemoteDescription(description);
  }

  void setCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);

    await peerConnection.addCandidate(candidate);
  }

  SizedBox videoRenderers() {
    return SizedBox(
      height: 210,
      child: Row(
        children: [
          Flexible(
            child: Container(
              key: Key('remote'),
              margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: BoxDecoration(color: Colors.black),
              child: RTCVideoView(remoteRenderer),
            ),
          )
        ],
      ),
    );
  }

  Row offerAndAnswerButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          ElevatedButton(
            onPressed: createOffer,
            child: Text('Offer'),
          ),
          ElevatedButton(
            onPressed: createAnswer,
            child: Text("Answer"),
          )
        ],
      );

  Padding sdpCandidateTF() => Padding(
        padding: EdgeInsets.all(16.0),
        child: TextField(
          controller: sdpController,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
          maxLength: TextField.noMaxLength,
        ),
      );

  Row sdpCandidateButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          ElevatedButton(
            onPressed: setRemoteDescription,
            child: Text('Set Remote Description'),
          ),
          ElevatedButton(onPressed: setCandidate, child: Text('Set Candidate'))
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              videoRenderers(),
              offerAndAnswerButtons(),
              sdpCandidateTF(),
              sdpCandidateButtons(),
            ],
          ),
        ));
  }
}
