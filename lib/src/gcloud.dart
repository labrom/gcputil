import 'dart:convert';
import 'dart:io';

import 'package:googleapis/cloudkms/v1.dart';
import 'package:googleapis/secretmanager/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';

/// Retrieves a secret from the platform's secret manager.
///
/// If the secret is exposed in an environment variable with the same name,
/// the secret value is directly returned from there. If not, this function
/// queries Google Cloud Secret Manager.
Future<String> secret(String name) async {
  final envSecret = Platform.environment[name];
  if (envSecret != null) {
    return envSecret;
  }

  final client = await clientViaMetadataServer();

  final secretManagerApi = SecretManagerApi(client);
  final secretPath =
      'projects/${await projectId}/secrets/$name/versions/latest';

  final response = await secretManagerApi.projects.secrets.versions.access(
    secretPath,
  );
  return String.fromCharCodes(response.payload!.dataAsBytes);
}

/// Encrypts a value using Google Cloud KMS.
Future<String?> encrypt(String value, EncryptionKey key) async {
  final client = await clientViaMetadataServer();
  final kmsApi = CloudKMSApi(client);
  final keyPath =
      'projects/${await projectId}/locations/${key.region}/keyRings/${key.ring}/cryptoKeys/${key.name}';
  final base64Bytes = base64.encode(utf8.encode(value));
  final encryptRequest = EncryptRequest.fromJson({
    'name': keyPath,
    'plaintext': base64Bytes,
  });
  final encryptResponse = await kmsApi.projects.locations.keyRings.cryptoKeys
      .encrypt(encryptRequest, keyPath);
  return encryptResponse.ciphertext;
}

/// Decrypts a value using Google Cloud KMS.
Future<String?> decrypt(String cipher, EncryptionKey key) async {
  final client = await clientViaMetadataServer();
  final kmsApi = CloudKMSApi(client);
  final keyPath =
      'projects/${await projectId}/locations/${key.region}/keyRings/${key.ring}/cryptoKeys/${key.name}';
  final decryptRequest = DecryptRequest.fromJson({
    'name': keyPath,
    'ciphertext': cipher,
  });
  final decryptResponse = await kmsApi.projects.locations.keyRings.cryptoKeys
      .decrypt(decryptRequest, keyPath);
  if (decryptResponse.plaintext == null) {
    return null;
  }
  return utf8.decode(base64.decode(decryptResponse.plaintext!));
}

/// Gets the current Google Cloud project's ID from the metadata service.
Future<String> get projectId async => (await get(
  Uri.parse(
    'http://metadata.google.internal/computeMetadata/v1/project/project-id',
  ),
  headers: {'Metadata-Flavor': 'Google'},
)).body;

/// Gets the runtime service account email from the metadata service.
Future<String> get runtimeServiceAccountEmail async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse(
        'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email',
      ),
    );
    request.headers.set('Metadata-Flavor', 'Google');

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'Failed to resolve runtime service account email: '
        '${response.statusCode} $body',
      );
    }

    final email = body.trim();
    if (email.isEmpty) {
      throw StateError(
        'Runtime service account email metadata response was empty.',
      );
    }

    return email;
  } finally {
    client.close(force: true);
  }
}

/// A Google Cloud project.
class Project {
  /// Constructor with projectId.
  const Project(this.id);

  /// The project's id (projectId).
  final String id;
}

/// A Google Cloud KMS encryption key.
class EncryptionKey {
  /// Constructor.
  EncryptionKey({
    required this.name,
    required this.ring,
    this.region = 'global',
  });

  /// The key name.
  final String name;

  /// The key ring.
  final String ring;

  /// The key region.
  final String region;
}
