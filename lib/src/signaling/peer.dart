/*
 * @Author: Beoyan
 * @Date: 2022-09-08 17:08:00
 * @LastEditTime: 2022-09-08 17:09:13
 * @LastEditors: Beoyan
 * @Description: 消费者模型
 */

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:haoxin_mediasoup/haoxin_mediasoup.dart';
import 'package:haoxin_mediasoup/src/signaling/peer_device.dart';

class Peer {
   Consumer? audio;
   Consumer? video;
  final PeerDevice device;
  final String displayName;
  final String peerId;
  RTCVideoRenderer? renderer;

  Peer({
    this.audio,
    this.video,
    this.renderer,
    required this.device,
    required this.displayName,
    required this.peerId,
  });

  Peer.fromMap(Map data)
      : peerId = data['id'],
        displayName = data['displayName'],
        device = PeerDevice.fromMap(data['device']),
        audio = null,
        video = null,
        renderer = null;

  List<String> get consumers => [
        if (audio != null) audio!.id,
        if (video != null) video!.id,
      ];
}
