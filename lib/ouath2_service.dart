import 'package:flutter/foundation.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'dart:io' show Platform;

class OAuth2Service {
  static OAuth2Service? _instance;
  late OAuth2Helper _oauth2Helper;

  OAuth2Service._() {
    final client = OAuth2Client(
      authorizeUrl: 'https://login.microsoftonline.com/de78aefd-fda9-4eaf-a2d1-cf8492188649/oauth2/v2.0/authorize',
      tokenUrl: 'https://login.microsoftonline.com/de78aefd-fda9-4eaf-a2d1-cf8492188649/oauth2/v2.0/token',
      redirectUri: kIsWeb ? 'https://interpage.pl/egzaminyzsel/redirect.html' : 'com.example.myapp://oauthredirect',
      customUriScheme: kIsWeb ? '' : 'com.example.myapp',
    );

    _oauth2Helper = OAuth2Helper(
      client,
      grantType: OAuth2Helper.authorizationCode,
      clientId: '67af475e-082d-4187-b1ef-5fa26fa0fe77',
      scopes: ['openid', 'profile', 'email', 'User.Read', 'offline_access'],
      enablePKCE: true,
      authCodeParams: {'response_mode': 'query'},
    );
  }

  static OAuth2Service get instance => _instance ??= OAuth2Service._();

  OAuth2Helper get oauth2Helper => _oauth2Helper;
}