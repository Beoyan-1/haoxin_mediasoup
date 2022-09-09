/*
 * @Author: Beoyan
 * @Date: 2022-09-08 13:26:03
 * @LastEditTime: 2022-09-09 09:12:13
 * @LastEditors: Beoyan
 * @Description: 
 */
import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:haoxin_mediasoup/haoxin_mediasoup.dart';
import 'package:haoxin_mediasoup/src/signaling/peer.dart';
import 'package:haoxin_mediasoup/src/signaling/web_socket.dart';
import 'package:haoxin_mediasoup/src/utils.dart';

class JoinMeetingParams {
  final String roomId;
  final String? peerId;
  final String url;
  final String displayName;

  JoinMeetingParams(
      {required this.roomId,
      this.peerId,
      required this.url,
      this.displayName = " "});
}

class JoinMeetingOptions {
  ///是否启用视频 默认true 启用
  bool enableVideo;

  ///是否启用音频 默认true 启用
  bool enableAudio;

  ///是否是生产者 默认true 启用
  bool isProduce;

  ///是否是消费者 默认true 启用
  bool isConsume;

  JoinMeetingOptions(
      {this.enableAudio = true,
      this.enableVideo = false,
      this.isProduce = true,
      this.isConsume = true});
}

class RoomClientRepository {
  final List<MediaDeviceInfo> _audioInputs = [];
  final List<MediaDeviceInfo> _audioOutputs = [];
  final List<MediaDeviceInfo> _videoInputs = [];

  List<Peer> _memberList = [];

  bool _closed = false;

  WebSocket? _webSocket;
  Device? _mediasoupDevice;
  Transport? _sendTransport;
  Transport? _recvTransport;
  bool _produce = false;
  bool _consume = true;
  // StreamSubscription<MediaDevicesState>? _mediaDevicesBlocSubscription;
  String? _audioInputDeviceId;
  String? _audioOutputDeviceId;
  String? _videoInputDeviceId;
  //加入会的设置
  late JoinMeetingOptions _joinMeetingOptions;
  //加入会议的参数
  late JoinMeetingParams _joinMeetingParams;

  static RoomClientRepository? _instance;

  RoomClientRepository._internal() {
    _initSDK();
  }

  // 工厂构造函数
  factory RoomClientRepository() {
    _instance ??= RoomClientRepository._internal();
    return _instance!;
  }

  ///初始化设备
  _initDevices() async {
    final List<MediaDeviceInfo> devices =
        await navigator.mediaDevices.enumerateDevices();
    for (var device in devices) {
      switch (device.kind) {
        case 'audioinput':
          _audioInputs.add(device);
          break;
        case 'audiooutput':
          _audioOutputs.add(device);
          break;
        case 'videoinput':
          _videoInputs.add(device);
          break;
        default:
          break;
      }
    }

    if (_audioInputs.isNotEmpty) {
      _audioInputDeviceId = _audioInputs.first.deviceId;
    }

    if (_audioOutputs.isNotEmpty) {
      _audioOutputDeviceId = _audioOutputs.first.deviceId;
    }

    if (_videoInputs.isNotEmpty) {
      _videoInputDeviceId = _videoInputs.first.deviceId;
    }
  }

  ///初始化 sdk
  _initSDK() async {
    await _initDevices();
  }

  ///加入会议室
  joinMeetingWithParams({
    required JoinMeetingParams params,
    JoinMeetingOptions? options,
    VoidCallback? onFail,
  }) {
    options ??= JoinMeetingOptions();
    _joinMeetingOptions = options;
    _consume = options.isConsume;
    _produce = options.isProduce;
    _joinMeetingParams = params;
    _webSocket = WebSocket(
      peerId: params.peerId ?? '${generateRandomNumber()}',
      roomId: params.roomId,
      url: params.url,
    );
    _webSocket!.onOpen = _joinRoom;
    _webSocket!.onFail = () {
      if (kDebugMode) {
        print('WebSocket connection failed');
      }
      if (onFail != null) {
        onFail();
      }
    };
    _webSocket!.onDisconnected = () {
      if (_sendTransport != null) {
        _sendTransport!.close();
        _sendTransport = null;
      }
      if (_recvTransport != null) {
        _recvTransport!.close();
        _recvTransport = null;
      }
    };
    _webSocket!.onClose = () {
      if (_closed) return;
      close();
    };

    _webSocket!.onRequest = (request, accept, reject) async {
      switch (request['method']) {
        case 'newConsumer':
          {
            if (!_consume) {
              reject(403, 'I do not want to consume');
              break;
            }
            try {
              _recvTransport!.consume(
                id: request['data']['id'],
                producerId: request['data']['producerId'],
                kind: RTCRtpMediaTypeExtension.fromString(
                    request['data']['kind']),
                rtpParameters:
                    RtpParameters.fromMap(request['data']['rtpParameters']),
                appData: Map<String, dynamic>.from(request['data']['appData']),
                peerId: request['data']['peerId'],
                accept: accept,
              );
            } catch (error) {
              if (kDebugMode) {
                print('newConsumer request failed: $error');
              }
              throw (error);
            }
            break;
          }
        case 'newDataConsumer':
          if (kDebugMode) {
            print('接受到消息 newDataConsumer');
          }
          _recvTransport!.consumeData(
              id: request['data']['id'],
              dataProducerId: request['data']['dataProducerId'],
              sctpStreamParameters: SctpStreamParameters.fromMap(
                  request['data']['sctpStreamParameters']),
              label: request['data']['label'],
              appData: request['data']['appData'],
              peerId: request['data']['peerId'],
              accept: accept);
          break;
        default:
          break;
      }
    };

    _webSocket!.onNotification = (notification) async {
      if (kDebugMode) {
        print("----------------通知   ${notification['method']}");
      }
      switch (notification['method']) {
        case 'producerScore': //生产者平分变化
          {
            String consumerId = notification['data']['producerId'];
            List score = notification['data']['score'];
            print("----------------测试   producerScore : ${score.toString()}");
            break;
          }
        case 'consumerScore': //消费者平分变化
          {
            String consumerId = notification['data']['consumerId'];
            Map score = notification['data']['score'];
            print("----------------测试   consumerScore : ${score.toString()}");
            break;
          }
        case 'consumerClosed':
          {
            String consumerId = notification['data']['consumerId'];

            break;
          }
        case 'consumerPaused':
          {
            String consumerId = notification['data']['consumerId'];

            break;
          }
        case 'consumerResumed':
          {
            String consumerId = notification['data']['consumerId'];

            break;
          }

        case 'newPeer':
          {
            final Map<String, dynamic> newPeer =
                Map<String, dynamic>.from(notification['data']);
            deallWithData(newPeer);
            break;
          }

        case 'peerClosed':
          {
            String peerId = notification['data']['peerId'];
            removePeer(peerId);
            break;
          }
        case 'consumerLayersChanged': //消费者状态发生改变
          {
            String consumerId = notification['data']["consumerId"];
            int spatialLayer = notification['data']["spatialLayer"];
            int temporalLayer = notification['data']["temporalLayer"];
            log("consumerLayersChanged---------consumerId：$consumerId -----spatialLayer : $spatialLayer -----temporalLayer : $temporalLayer");
            break;
          }
        case 'peerDisplayNameChanged': //名字改变
          {
            String peerId = notification['data']["peerId"];
            String displayName = notification['data']["displayName"];
            String oldDisplayName = notification['data']["oldDisplayName"];
            log("peerDisplayNameChanged---------consumerId：$peerId -----displayName : $displayName -----oldDisplayName : $oldDisplayName");
            break;
          }

        default:
          break;
      }
    };
  }

  void join() {}
  // RoomClientRepository({
  //   required this.roomId,
  //   required this.peerId,
  //   required this.url,
  //   required this.displayName,
  // }) {
  // _mediaDevicesBlocSubscription =
  //     mediaDevicesBloc.stream.listen((MediaDevicesState state) async {
  //   if (state.selectedAudioInput != null &&
  //       state.selectedAudioInput?.deviceId != audioInputDeviceId) {

  //   }

  //   if (state.selectedVideoInput != null &&
  //       state.selectedVideoInput?.deviceId != videoInputDeviceId) {

  //   }
  // });
  // }

  void close() {
    if (_closed) {
      return;
    }
    _webSocket?.close();
    if (_sendTransport != null) {
      _sendTransport!.close();
    }
    if (_recvTransport != null) {
      _recvTransport!.close();
    }
    _closed = true;
    // _mediaDevicesBlocSubscription?.cancel();
  }

  Future<dynamic> disableMic() async {
    try {
      return await _webSocket!.socket.request('closeProducer', {
        'producerId': _audioInputDeviceId,
      });
    } catch (error) {
      return error;
    }
  }

  Future<void> disableWebcam() async {
    await _webSocket!.socket.request('closeProducer', {
      'producerId': _videoInputDeviceId,
    });
  }

  Future<void> muteMic() async {
    // producersBloc.add(ProducerPaused(source: 'mic'));

    // try {
    //   await _webSocket!.socket.request('pauseProducer', {
    //     'producerId': producersBloc.state.mic!.id,
    //   });
    // } catch (error) {}
  }

  Future<void> unmuteMic() async {
    // producersBloc.add(ProducerResumed(source: 'mic'));

    // try {
    //   await _webSocket!.socket.request('resumeProducer', {
    //     'producerId': producersBloc.state.mic!.id,
    //   });
    // } catch (error) {}
  }

  void _producerCallback(Producer producer) {
    // if (producer.source == 'webcam') {
    //   meBloc.add(MeSetWebcamInProgress(progress: false));
    // }
    // producer.on('trackended', () {
    //   disableMic().catchError((data) {});
    // });
    // producersBloc.add(ProducerAdd(producer: producer));
  }

  void _consumerCallback(Consumer consumer, [dynamic accept]) {
    accept({});
    for (var element in _memberList) {
      if (element.peerId == consumer.peerId) {
        if (consumer.kind == 'audio') {
          element.audio = consumer.copyWith();
        } else if (consumer.kind == 'video') {
          element.video = consumer.copyWith();
          element.renderer = RTCVideoRenderer();
        }
      }
    }
  }

  //接收消息通道
  void _dataConsumerCallback(DataConsumer dataConsumer, [dynamic accept]) {
    accept({});

    dataConsumer.dataChannel.onMessage = (data) {
      print(data);
      // Fluttertoast.showToast(
      //     msg: data.text,
      //     toastLength: Toast.LENGTH_SHORT,
      //     gravity: ToastGravity.CENTER,
      //     timeInSecForIosWeb: 1,
      //     backgroundColor: Colors.red,
      //     textColor: Colors.white,
      //     fontSize: 16.0);
    };
    // dataConsumer.on('message', (message) {
    //   switch (dataConsumer.label) {
    //     case 'chat':
    //       print(message);
    //       RTCDataChannelMessage dataChannelMessage = message["data"];

    //       dataChannelMessage.text;
    //       break;
    //     case 'bot':
    //       break;
    //     default:
    //   }
    // });
  }

  //设置当前消费者的时间层空间层
  void setConsumerPreferredLayers(consumerid, s, l) {
    _webSocket!.setConsumerPreferredLayers(consumerid, s, l);
  }

  Future<MediaStream> createAudioStream() async {
    // audioInputDeviceId = mediaDevicesBloc.state.selectedAudioInput!.deviceId;
    Map<String, dynamic> mediaConstraints = {
      'audio': {
        'optional': [
          {
            'sourceId': _audioInputDeviceId,
          },
        ],
      },
    };
    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    return stream;
  }

  Future<MediaStream> createVideoStream({bool userScreen = false}) async {
    Map<String, dynamic> mediaConstraints = <String, dynamic>{
      'audio': userScreen ? false : true,
      'video': userScreen
          ? true
          : {
              'mandatory': {
                'width': '1280',
                // Provide your own width, height and frame rate here
                'height': '720',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [
                {'sourceId': _videoInputDeviceId}
              ],
            }
    };

    MediaStream stream = userScreen
        ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
        : await navigator.mediaDevices.getUserMedia(mediaConstraints);

    return stream;
  }

  void enableWebcam() async {
    if (_mediasoupDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo) ==
        false) {
      return;
    }
    MediaStream? videoStream;
    MediaStreamTrack? track;
    try {
      // NOTE: prefer using h264
      final videoVPVersion = kIsWeb ? 9 : 9; //更换vp8 或者 vp9
      RtpCodecCapability? codec = _mediasoupDevice!.rtpCapabilities.codecs
          .firstWhere(
              (RtpCodecCapability c) => c.mimeType.toLowerCase() == 'video/vp9',
              orElse: () =>
                  throw 'desired vp$videoVPVersion codec+configuration is not supported');
      videoStream = await createVideoStream();
      track = videoStream.getVideoTracks().first;
      // meBloc.add(MeSetWebcamInProgress(progress: true));
      _sendTransport!.produce(
        stream: videoStream,
        track: track,
        codecOptions: ProducerCodecOptions(
          videoGoogleStartBitrate: 1000,
          videoGoogleMinBitrate: 1000,
        ),
        encodings: [
          // RtpEncodingParameters(
          //   //h264 S1T1 vp9  S3T3_KEY
          //   // scalabilityMode: 'S1T1',
          //   rid: 'h',
          //   scaleResolutionDownBy: 1,
          //   maxBitrate: 5000000,
          //   dtx: true,
          //   active: true,
          // ),
          // RtpEncodingParameters(
          //   scaleResolutionDownBy: 1,
          //   // maxBitrate: 1000000,
          //   minBitrate: 756000,

          //   dtx: false,
          //   active: true,
          // ),
          // RtpEncodingParameters(
          //   //h264 S1T1 vp9  S3T3_KEY
          //   // scalabilityMode: 'S1T1',

          //   scaleResolutionDownBy: 2,

          //   maxBitrate: 756000,
          //   minBitrate: 477557,
          //   dtx: false,
          //   active: true,
          // ),

          // RtpEncodingParameters(
          //   //h264 S1T1 vp9  S3T3_KEY
          //   scalabilityMode: 'S1T1_KEY',
          //   rid: 'l',
          //   scaleResolutionDownBy: 4,
          //   maxBitrate: 100000,
          //   active: true,
          // ),

          // VP9 SVC
          RtpEncodingParameters(
            scalabilityMode: 'S2T3', //h264 S1T1 vp9  S3T3_KEY
            // scaleResolutionDownBy: 1.0,
            dtx: true,
            // priority: Priority.High,
            active: true,
          ),
          //联播
          // RtpEncodingParameters(
          //   scalabilityMode: 'S3T3_KEY', //h264 S1T1 vp9  S3T3_KEY
          //   dtx: true,
          //   // priority: Priority.High,
          //   maxBitrate: 900000,
          //   active: true,
          // ),

          // RtpEncodingParameters(
          //   scalabilityMode: 'S1T1', //h264 S1T1 vp9  S3T3_KEY
          //   // scaleResolutionDownBy: 1.0,
          //   // dtx: true,
          //   // priority: Priority.High,
          //   maxBitrate: 15000,
          //   active: true,
          // ),
          // RtpEncodingParameters(
          //     // scalabilityMode: 'S3T3_KEY', //h264 S1T1 vp9  S3T3_KEY
          //     scaleResolutionDownBy: 2.0,
          //     // dtx: true,
          //     // priority: Priority.High,
          //     active: true,
          //     maxBitrate: 300000,
          //     rid: 'q'),
        ],
        appData: {
          'source': 'webcam',
        },
        source: 'webcam',
        codec: codec,
      );
    } catch (error) {
      if (videoStream != null) {
        await videoStream.dispose();
      }
    }
  }

  void enableMic() async {
    if (_mediasoupDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeAudio) ==
        false) {
      return;
    }

    MediaStream? audioStream;
    MediaStreamTrack? track;
    try {
      audioStream = await createAudioStream();
      track = audioStream.getAudioTracks().first;
      _sendTransport!.produce(
        track: track,
        codecOptions: ProducerCodecOptions(opusStereo: 1, opusDtx: 1),
        stream: audioStream,
        appData: {
          'source': 'mic',
        },
        source: 'mic',
      );
    } catch (error) {
      if (audioStream != null) {
        await audioStream.dispose();
      }
    }
  }

  Future<void> _joinRoom() async {
    try {
      _mediasoupDevice = Device();
      _closed = false;
      dynamic routerRtpCapabilities =
          await _webSocket!.socket.request('getRouterRtpCapabilities', {});

      if (kDebugMode) {
        print('协商的能力  $routerRtpCapabilities');
      }

      final rtpCapabilities = RtpCapabilities.fromMap(routerRtpCapabilities);
      rtpCapabilities.headerExtensions
          .removeWhere((he) => he.uri == 'urn:3gpp:video-orientation');
      await _mediasoupDevice!.load(routerRtpCapabilities: rtpCapabilities);

      if (_mediasoupDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeAudio) ==
              true ||
          _mediasoupDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo) ==
              true) {
        _produce = true;
      }

      ///添加权限限制
      if (_produce) {
        _produce = _joinMeetingOptions.isProduce;
      }

      if (_produce) {
        Map transportInfo =
            await _webSocket!.socket.request('createWebRtcTransport', {
          'forceTcp': false,
          'producing': true,
          'consuming': false,
          'sctpCapabilities': _mediasoupDevice!.sctpCapabilities.toMap(),
        });

        _sendTransport = _mediasoupDevice!.createSendTransportFromMap(
          transportInfo,
          producerCallback: _producerCallback,
        );

        _sendTransport!.on('connect', (Map data) {
          _webSocket!.socket
              .request('connectWebRtcTransport', {
                'transportId': _sendTransport!.id,
                'dtlsParameters': data['dtlsParameters'].toMap(),
              })
              .then(data['callback'])
              .catchError(data['errback']);
        });

        _sendTransport!.on('produce', (Map data) async {
          try {
            Map response = await _webSocket!.socket.request(
              'produce',
              {
                'transportId': _sendTransport!.id,
                'kind': data['kind'],
                'rtpParameters': data['rtpParameters'].toMap(),
                if (data['appData'] != null)
                  'appData': Map<String, dynamic>.from(data['appData'])
              },
            );

            data['callback'](response['id']);
          } catch (error) {
            data['errback'](error);
          }
        });

        _sendTransport!.on('producedata', (data) async {
          try {
            Map response = await _webSocket!.socket.request('produceData', {
              'transportId': _sendTransport!.id,
              'sctpStreamParameters': data['sctpStreamParameters'].toMap(),
              'label': data['label'],
              'protocol': data['protocol'],
              'appData': data['appData'],
            });

            data['callback'](response['id']);
          } catch (error) {
            data['errback'](error);
          }
        });
      }

      if (_consume) {
        Map transportInfo = await _webSocket!.socket.request(
          'createWebRtcTransport',
          {
            'forceTcp': false,
            'producing': false,
            'consuming': true,
            'sctpCapabilities': _mediasoupDevice!.sctpCapabilities.toMap(),
          },
        );

        _recvTransport = _mediasoupDevice!.createRecvTransportFromMap(
          transportInfo,
          consumerCallback: _consumerCallback,
          dataConsumerCallback: _dataConsumerCallback,
        );

        _recvTransport!.on(
          'connect',
          (data) {
            _webSocket!.socket
                .request(
                  'connectWebRtcTransport',
                  {
                    'transportId': _recvTransport!.id,
                    'dtlsParameters': data['dtlsParameters'].toMap(),
                  },
                )
                .then(data['callback'])
                .catchError(data['errback']);
          },
        );
      }

      Map response = await _webSocket!.socket.request('join', {
        'displayName': _joinMeetingParams.displayName,
        'device': {
          'name': _joinMeetingParams.displayName,
          'flag': 'flutter',
          'version': '0.9.2',
        },
        'rtpCapabilities': _mediasoupDevice!.rtpCapabilities.toMap(),
        'sctpCapabilities': _mediasoupDevice!.sctpCapabilities.toMap(),
      });

      response['peers'].forEach((value) {
        deallWithData(value);
      });

      if (_produce) {
        enableMic();
        enableWebcam();

        _sendTransport!.on('connectionstatechange', (connectionState) {
          if (connectionState == 'connected') {
            // enableChatDataProducer();
            // enableBotDataProducer();
          }
        });
      }
    } catch (error) {
      if (kDebugMode) {
        print(error);
      }
      close();
    }
  }

  //处理参会人
  deallWithData(dynamic map) {
    for (var element in _memberList) {
      if (element.peerId == map["id"]) {
        _memberList.remove(element);
      }
    }
    _memberList.add(Peer.fromMap(map));
  }

  //移除参会者
  removePeer(String id) {
    for (var element in _memberList) {
      if (element.peerId == id) {
        _memberList.remove(element);
      }
    }
  }
}
