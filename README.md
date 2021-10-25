# web_socket_support_platform_interface
[![Pub Version](https://img.shields.io/pub/v/web_socket_support_platform_interface)](https://pub.dev/packages/web_socket_support_platform_interface) ![github actions](https://github.com/sharpbitstudio/flutter-websocket-support-platform-interface/actions/workflows/master_build.yaml/badge.svg?branch=master) [![codecov](https://codecov.io/gh/sharpbitstudio/flutter-websocket-support-platform-interface/branch/master/graph/badge.svg?token=048H5HLA09)](https://codecov.io/gh/sharpbitstudio/flutter-websocket-support-platform-interface)

A common platform interface for the web_socket_support plugin.

This interface allows platform-specific implementations of the web_socket_support plugin, as well as 
the plugin itself, to ensure they are supporting the same interface.

## Usage

To implement a new platform-specific implementation of web_socket_support, extend WebSocketSupportPlatform 
with an implementation that performs the platform-specific behavior, and when you register your plugin, 
set the default WebSocketSupportPlatform by calling WebSocketSupportPlatform.instance = MyWebSocketSupportPlatform().

