import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:haoxin_mediasoup/src/handlers/sdp/media_section.dart';
import 'package:haoxin_mediasoup/src/rtp_parameters.dart';
import 'package:haoxin_mediasoup/src/sdp_object.dart';
import 'package:haoxin_mediasoup/src/transport.dart';


class PlainRtpUtils {
  static PlainRtpParameters extractPlainRtpParameters(
    SdpObject sdpObject,
    RTCRtpMediaType kind,
  ) {
    MediaObject? mediaObject = sdpObject.media.firstWhere(
      (MediaObject m) => m.type == RTCRtpMediaTypeExtension.value(kind),
      orElse: () => null as MediaObject,
    );

    if (mediaObject == null) {
      throw ('m=${RTCRtpMediaTypeExtension.value(kind)} section not found');
    }

    Connection connectionObject =
        (mediaObject.connection ?? sdpObject.connection)!;

    PlainRtpParameters result = PlainRtpParameters(
      ip: connectionObject.ip,
      ipVersion: connectionObject.version,
      port: mediaObject.port!,
    );

    return result;
  }

  static List<RtpEncodingParameters> getRtpEncodings(
    SdpObject sdpObject,
    RTCRtpMediaType kind,
  ) {
    MediaObject? mediaObject = sdpObject.media.firstWhere(
      (MediaObject m) => m.type == RTCRtpMediaTypeExtension.value(kind),
      orElse: () => null as MediaObject,
    );

    if (mediaObject == null) {
      throw ('m=${RTCRtpMediaTypeExtension.value(kind)} section not found');
    }

    if (mediaObject.ssrcs != null || mediaObject.ssrcs!.isNotEmpty) {
      Ssrc ssrc = mediaObject.ssrcs!.first;
      RtpEncodingParameters result = RtpEncodingParameters(ssrc: ssrc.id);

      return <RtpEncodingParameters>[result];
    }

    return <RtpEncodingParameters>[];
  }
}
