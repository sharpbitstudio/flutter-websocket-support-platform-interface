import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_support_platform_interface/method_channel_web_socket_support.dart';
import 'package:web_socket_support_platform_interface/web_socket_exception.dart';
import 'package:web_socket_support_platform_interface/web_socket_options.dart';

import 'event_channel_mock.dart';
import 'method_channel_mock.dart';
import 'test_web_socket_listener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$MethodChannelWebSocketSupport calls TO platform', () {
    test('Send `connect` event before we is established', () async {
      final testWsListener = TestWebSocketListener();
      final webSocketSupport = MethodChannelWebSocketSupport(testWsListener);

      // Arrange
      final completer = Completer();
      final methodChannel = MethodChannelMock(
        channelName: MethodChannelWebSocketSupport.methodChannelName,
        methodMocks: [
          MethodMock(
            method: 'connect',
            action: () {
              _sendMessageFromPlatform(
                  MethodChannelWebSocketSupport.methodChannelName,
                  const MethodCall('onOpened'));
              completer.complete();
            },
            result: true,
          ),
        ],
      );

      // Act
      final commandSent = await webSocketSupport.connect(
        'ws://example.com/',
        options: const WebSocketOptions(
          autoReconnect: true,
        ),
      );

      // await completer
      await completer.future;

      // Assert
      // connect returns true if command is accepted
      expect(commandSent, isTrue);
      // correct event sent to platform
      expect(
        methodChannel.log,
        <Matcher>[
          isMethodCall('connect', arguments: <String, Object>{
            'serverUrl': 'ws://example.com/',
            'options': {
              'autoReconnect': true,
              'pingInterval': 0,
              'headers': {},
            },
          }),
        ],
      );

      // platform response 'onOpened' created wsConnection
      expect(testWsListener.webSocketConnection, isNotNull);

      // clean up
      await testWsListener.destroy();
    });

    test('Send `text` message after ws is established', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // Arrange
      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // method channel mock
      final methodChannel = MethodChannelMock(
        channelName: MethodChannelWebSocketSupport.methodChannelName,
        methodMocks: [
          MethodMock(
            method: 'sendStringMessage',
            result: true,
          ),
        ],
      );

      // Act - send text message
      final commandSent = await testWsListener.webSocketConnection!
          .sendStringMessage('test payload 1');

      // Assert
      // command returns true if it is accepted
      expect(commandSent, isTrue);
      // correct event sent to platform
      expect(
        methodChannel.log,
        <Matcher>[
          isMethodCall('sendStringMessage', arguments: 'test payload 1'),
        ],
      );

      // clean up
      await testWsListener.destroy();
    });

    test('Send `binary` message after ws is established', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // Arrange
      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // method channel mock
      final methodChannel = MethodChannelMock(
        channelName: MethodChannelWebSocketSupport.methodChannelName,
        methodMocks: [
          MethodMock(
            method: 'sendByteArrayMessage',
            result: true,
          ),
        ],
      );

      // Act - send text message
      final commandSent = await testWsListener.webSocketConnection!
          .sendByteArrayMessage(Uint8List.fromList('test payload 2'.codeUnits));

      // Assert
      // command returns true if it is accepted
      expect(commandSent, isTrue);
      // correct event sent to platform
      expect(
        methodChannel.log,
        <Matcher>[
          isMethodCall('sendByteArrayMessage',
              arguments: 'test payload 2'.codeUnits),
        ],
      );

      // clean up
      await testWsListener.destroy();
    });

    test('Send `disconnect` event after we is established', () async {
      final testWsListener = TestWebSocketListener();
      final webSocketSupport = MethodChannelWebSocketSupport(testWsListener);

      // Arrange
      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      final completer = Completer();
      final methodChannel = MethodChannelMock(
        channelName: MethodChannelWebSocketSupport.methodChannelName,
        methodMocks: [
          MethodMock(
            method: 'disconnect',
            action: () {
              _sendMessageFromPlatform(
                  MethodChannelWebSocketSupport.methodChannelName,
                  const MethodCall('onClosed',
                      <String, Object>{'code': 123, 'reason': 'test reason'}));
              completer.complete();
            },
            result: true,
          ),
        ],
      );

      // Act -> disconnect
      final commandSent =
          await webSocketSupport.disconnect(code: 123, reason: 'test reason');

      // await completer
      await completer.future;

      // Assert
      // command returns true if it is accepted
      expect(commandSent, isTrue);
      // correct event sent to platform
      expect(
        methodChannel.log,
        <Matcher>[
          isMethodCall('disconnect', arguments: <String, Object>{
            'code': 123,
            'reason': 'test reason',
          }),
        ],
      );

      // platform response 'onOpened' created wsConnection
      expect(testWsListener.webSocketConnection, isNotNull);

      // clean up
      await testWsListener.destroy();
    });
  });

  group('$MethodChannelWebSocketSupport calls FROM platform', () {
    test('Receive `onOpened` event from platform', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // action
      // execute methodCall from platform
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // verify
      expect(testWsListener.webSocketConnection, isNotNull);

      // clean up
      await testWsListener.destroy();
    });

    test('Receive `onClosing` event from platform', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // action
      // execute methodCall from platform
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onClosing',
              <String, Object>{'code': 234, 'reason': 'test reason 2'}));

      // verify
      expect(testWsListener.onClosingCalled, true);
      expect(testWsListener.closingCode, 234);
      expect(testWsListener.closingReason, 'test reason 2');

      // clean up
      await testWsListener.destroy();
    });

    test('Receive `onClosed` event from platform', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // action
      // execute methodCall from platform
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onClosed',
              <String, Object>{'code': 345, 'reason': 'test reason 3'}));

      // verify
      expect(testWsListener.onClosedCalled, true);
      expect(testWsListener.closingCode, 345);
      expect(testWsListener.closingReason, 'test reason 3');

      // clean up
      await testWsListener.destroy();
    });

    test('Receive `onFailure` event from platform', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // action
      // execute methodCall from platform
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onFailure', <String, Object>{
            'throwableType': 'TestType',
            'errorMessage': 'TestErrMsg',
            'causeMessage': 'TestErrCause'
          }));

      // verify
      expect(testWsListener.onErrorCalled, true);
      expect(testWsListener.exception, isInstanceOf<WebSocketException>());
      expect(testWsListener.exception.toString(),
          'WebSocketException[type:TestType, message:TestErrMsg, cause:TestErrCause]');

      // clean up
      await testWsListener.destroy();
    });

    test('Receive unexpected event from platform', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // action
      // execute methodCall from platform
      expect(
          _sendMessageFromPlatform(
              MethodChannelWebSocketSupport.methodChannelName,
              const MethodCall('invalid_call'), callback: (data) {
            const StandardMethodCodec().decodeEnvelope(data!);
          }),
          throwsA(predicate((e) =>
              e is PlatformException &&
              e.code ==
                  MethodChannelWebSocketSupport.methodChannelExceptionCode &&
              e.message ==
                  MethodChannelWebSocketSupport.unexpectedMethodNameMessage &&
              e.details == 'invalid_call')));

      // clean up
      await testWsListener.destroy();
    });

    test('Receive event from platform via textEventChannel', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // prepare
      // text message channel mock (before we is opened)
      final streamController = StreamController<String>.broadcast();
      EventChannelMock(
        channelName: MethodChannelWebSocketSupport.textEventChannelName,
        stream: streamController.stream,
      );

      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // action
      // emit test event
      streamController.add('Text message 1');

      // verify
      expect(testWsListener.webSocketConnection, isNotNull);
      expect(
          await testWsListener.textQueue.next
              .timeout(const Duration(seconds: 1)),
          'Text message 1');

      // clean up
      await testWsListener.destroy();
    });

    test('Receive error event from platform via textEventChannel', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // prepare
      // text message channel mock (before we is opened)
      final streamController = StreamController<String>.broadcast();
      EventChannelMock(
        channelName: MethodChannelWebSocketSupport.textEventChannelName,
        stream: streamController.stream,
      );

      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // action
      // emit test error event
      streamController.addError(
        PlatformException(
            code: 'ERROR_CODE_3', message: 'errMsg3', details: null),
      );

      // verify
      expect(testWsListener.webSocketConnection, isNotNull);

      await testWsListener.errorCompleter.future
          .timeout(const Duration(seconds: 1));
      expect(testWsListener.onErrorCalled, true);
      expect(testWsListener.exception, isInstanceOf<PlatformException>());
      expect(testWsListener.exception.toString(),
          'PlatformException(ERROR_CODE_3, errMsg3, null, null)');

      // clean up
      await testWsListener.destroy();
    });

    test('Receive event from platform via byteEventChannel', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // prepare
      // byte array message channel mock (before ws is opened)
      final streamController = StreamController<Uint8List>.broadcast();
      EventChannelMock(
        channelName: MethodChannelWebSocketSupport.byteEventChannelName,
        stream: streamController.stream,
      );

      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // action
      // emit test event
      streamController.add(Uint8List.fromList('Binary message 1'.codeUnits));

      // verify
      expect(testWsListener.webSocketConnection, isNotNull);
      expect(
          await testWsListener.byteQueue.next
              .timeout(const Duration(seconds: 1)),
          'Binary message 1'.codeUnits);

      // clean up
      await testWsListener.destroy();
    });

    test('Receive error event from platform via byteEventChannel', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // prepare
      // byte array message channel mock (before ws is opened)
      final streamController = StreamController<Uint8List>.broadcast();
      EventChannelMock(
        channelName: MethodChannelWebSocketSupport.byteEventChannelName,
        stream: streamController.stream,
      );

      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // action
      // emit error test event
      streamController.addError(
        PlatformException(
            code: 'ERROR_CODE_4', message: 'errMsg4', details: null),
      );

      // verify
      expect(testWsListener.webSocketConnection, isNotNull);

      await testWsListener.errorCompleter.future
          .timeout(const Duration(seconds: 1));
      expect(testWsListener.onErrorCalled, true);
      expect(testWsListener.exception, isInstanceOf<PlatformException>());
      expect(testWsListener.exception.toString(),
          'PlatformException(ERROR_CODE_4, errMsg4, null, null)');

      // clean up
      await testWsListener.destroy();
    });

    test('Receive `onStringMessage` event via MethodChannel', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // Arrange
      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // Act -> onStringMessage
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onStringMessage', 'Fallback message 1'));

      // verify
      expect(testWsListener.webSocketConnection, isNotNull);
      expect(
          await testWsListener.textQueue.next
              .timeout(const Duration(seconds: 1)),
          'Fallback message 1');

      // clean up
      await testWsListener.destroy();
    });

    test('Receive `onByteArrayMessage` event via MethodChannel', () async {
      final testWsListener = TestWebSocketListener();
      MethodChannelWebSocketSupport(testWsListener);

      // Arrange
      // open ws
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          const MethodCall('onOpened'));

      // Act -> onByteArrayMessage
      await _sendMessageFromPlatform(
          MethodChannelWebSocketSupport.methodChannelName,
          MethodCall('onByteArrayMessage',
              Uint8List.fromList('Fallback message 2'.codeUnits)));

      // verify
      expect(testWsListener.webSocketConnection, isNotNull);
      expect(
          await testWsListener.byteQueue.next
              .timeout(const Duration(seconds: 1)),
          'Fallback message 2'.codeUnits);

      // clean up
      await testWsListener.destroy();
    });
  });
}

Future<ByteData?> _sendMessageFromPlatform(
    String channelName, MethodCall methodCall,
    {Function(ByteData?)? callback}) {
  final envelope = const StandardMethodCodec().encodeMethodCall(methodCall);
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channelName, envelope, callback);
}
