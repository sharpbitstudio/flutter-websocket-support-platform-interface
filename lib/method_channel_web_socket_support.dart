import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:web_socket_support_platform_interface/web_socket_exception.dart';
import 'package:web_socket_support_platform_interface/web_socket_connection.dart';
import 'package:web_socket_support_platform_interface/web_socket_listener.dart';
import 'package:web_socket_support_platform_interface/web_socket_options.dart';
import 'package:web_socket_support_platform_interface/web_socket_support_platform_interface.dart';

class MethodChannelWebSocketSupport extends WebSocketSupportPlatform {
  //
  // constants
  static const methodChannelName =
      'tech.sharpbitstudio.web_socket_support/methods';
  static const textEventChannelName =
      'tech.sharpbitstudio.web_socket_support/text-messages';
  static const byteEventChannelName =
      'tech.sharpbitstudio.web_socket_support/binary-messages';
  static const methodChannelExceptionCode = 'METHOD_CHANNEL_EXCEPTION';
  static const unexpectedMethodNameMessage = 'Unexpected method channel name';

  //
  // locals
  final WebSocketListener _listener;
  final MethodChannel _methodChannel;
  final EventChannel _textMessagesChannel;
  final EventChannel _byteMessagesChannel;

  // stream subscriptions
  StreamSubscription? _textStreamSubscription;
  StreamSubscription? _binaryStreamSubscription;

  MethodChannelWebSocketSupport(this._listener)
      : _methodChannel = const MethodChannel(methodChannelName),
        _textMessagesChannel = const EventChannel(textEventChannelName),
        _byteMessagesChannel = const EventChannel(byteEventChannelName) {
    // set method channel listener
    _methodChannel.setMethodCallHandler((MethodCall call) {
      switch (call.method) {
        case 'onOpened':
          // ws established
          _listener.onWsOpened(DefaultWebSocketConnection(_methodChannel));
          _addStreamEventListeners();
          break;
        case 'onClosing':
          final args = call.arguments as Map;
          final code = args['code'] ?? 4000; // map[] returns nullable value
          _listener.onWsClosing(code, args['reason'] ?? '');
          break;
        case 'onClosed':
          // ws closed
          final args = call.arguments as Map;
          final code = args['code'] ?? 4000; // map[] returns nullable value
          _listener.onWsClosed(code, args['reason'] ?? '');
          _removeStreamEventListeners();
          break;
        case 'onFailure':
          final args = call.arguments as Map;
          _listener.onError(WebSocketException(args['throwableType'],
              args['errorMessage'], args['causeMessage']));
          break;
        case 'onStringMessage':
          _listener.onStringMessage(call.arguments as String);
          break;
        case 'onByteArrayMessage':
          _listener.onByteArrayMessage(call.arguments as Uint8List);
          break;
        default:
          throw PlatformException(
              code: methodChannelExceptionCode,
              message: unexpectedMethodNameMessage,
              details: call.method);
      }
      return Future.value(null);
    });
  }

  /// This constructor is only used for testing and shouldn't be accessed by
  /// users of the plugin. It may break or change at any time.
  @visibleForTesting
  MethodChannelWebSocketSupport.private(this._listener, this._methodChannel,
      this._textMessagesChannel, this._byteMessagesChannel);

  /// obtain WebSocketListener implementation
  @visibleForTesting
  WebSocketListener get listener => _listener;

  @override
  Future<bool?> connect(
    String serverUrl, {
    WebSocketOptions options = const WebSocketOptions(),
  }) {
    // connect to server
    return _methodChannel.invokeMethod<bool>(
      'connect',
      <String, Object>{
        'serverUrl': serverUrl,
        'options': options.toMap(),
      },
    );
  }

  @override
  Future<bool?> disconnect({int code = 1000, String reason = 'Client done.'}) {
    return _methodChannel.invokeMethod<bool>(
      'disconnect',
      <String, Object>{
        'code': code,
        'reason': reason,
      },
    );
  }

  void _addStreamEventListeners() {
    // add text message listener
    _textStreamSubscription =
        _textMessagesChannel.receiveBroadcastStream().listen((message) {
      _listener.onStringMessage(message as String);
    }, onError: (e) {
      _listener.onError(e);
    });

    // add byte messages listener
    _binaryStreamSubscription =
        _byteMessagesChannel.receiveBroadcastStream().listen((message) {
      _listener.onByteArrayMessage(message as Uint8List);
    }, onError: (e) {
      _listener.onError(e);
    });
  }

  void _removeStreamEventListeners() {
    // remove text message listener
    _textStreamSubscription!.cancel();
    _textStreamSubscription = null;

    // remove byte messages listener
    _binaryStreamSubscription!.cancel();
    _binaryStreamSubscription = null;
  }
}
