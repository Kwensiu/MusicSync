import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HttpServerSecurityMaterial {
  // TODO(http-fingerprint): expose a SHA-256 fingerprint for the generated
  // certificate so discovery/handshake can pin HTTPS peers instead of trusting
  // any self-signed certificate.
  const HttpServerSecurityMaterial({
    required this.privateKeyPem,
    required this.certificatePem,
  });

  final String privateKeyPem;
  final String certificatePem;

  SecurityContext toSecurityContext() {
    final SecurityContext context = SecurityContext();
    context.useCertificateChainBytes(utf8.encode(certificatePem));
    context.usePrivateKeyBytes(utf8.encode(privateKeyPem));
    return context;
  }
}

class HttpSecurityContextStore {
  static const String _privateKeyKey = 'http_tls_private_key';
  static const String _certificateKey = 'http_tls_certificate';

  Future<HttpServerSecurityMaterial> loadOrCreate() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? privateKeyPem = preferences.getString(_privateKeyKey);
    final String? certificatePem = preferences.getString(_certificateKey);
    if (privateKeyPem != null &&
        privateKeyPem.isNotEmpty &&
        certificatePem != null &&
        certificatePem.isNotEmpty) {
      return HttpServerSecurityMaterial(
        privateKeyPem: privateKeyPem,
        certificatePem: certificatePem,
      );
    }

    final AsymmetricKeyPair<PublicKey, PrivateKey> keyPair =
        CryptoUtils.generateRSAKeyPair();
    final RSAPrivateKey privateKey = keyPair.privateKey as RSAPrivateKey;
    final RSAPublicKey publicKey = keyPair.publicKey as RSAPublicKey;
    final Map<String, String> distinguishedName = <String, String>{
      'CN': 'MusicSync Device',
      'O': 'MusicSync',
      'OU': '',
      'L': '',
      'S': '',
      'C': '',
    };
    final String csr = X509Utils.generateRsaCsrPem(
      distinguishedName,
      privateKey,
      publicKey,
    );
    final String generatedCertificate = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      3650,
    );
    final String generatedPrivateKey =
        CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey);

    await preferences.setString(_privateKeyKey, generatedPrivateKey);
    await preferences.setString(_certificateKey, generatedCertificate);

    return HttpServerSecurityMaterial(
      privateKeyPem: generatedPrivateKey,
      certificatePem: generatedCertificate,
    );
  }
}
