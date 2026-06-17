import 'dart:convert';
import 'dart:io';

import 'package:googleapis/cloudkms/v1.dart';
import 'package:googleapis/secretmanager/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';

const _metadataBaseUrl = 'http://metadata.google.internal/computeMetadata/v1';
const _metadataHeaders = {'Metadata-Flavor': 'Google'};

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
Future<String?> encrypt(
  String value,
  EncryptionKey key, {
  AuthClient? client,
  String? additionalAuthenticatedData,
}) async {
  final authClient = client ?? await clientViaMetadataServer();
  final kmsApi = CloudKMSApi(authClient);
  final keyPath = await _keyPath(key);
  final encryptRequest = EncryptRequest(
    plaintext: _base64Encode(value),
    additionalAuthenticatedData: _base64Encode(additionalAuthenticatedData),
  );
  final encryptResponse = await kmsApi.projects.locations.keyRings.cryptoKeys
      .encrypt(encryptRequest, keyPath);
  return encryptResponse.ciphertext;
}

/// Decrypts a value using Google Cloud KMS.
Future<String?> decrypt(
  String cipher,
  EncryptionKey key, {
  AuthClient? client,
  String? additionalAuthenticatedData,
}) async {
  final authClient = client ?? await clientViaMetadataServer();
  final kmsApi = CloudKMSApi(authClient);
  final keyPath = await _keyPath(key);
  final decryptRequest = DecryptRequest(
    ciphertext: cipher,
    additionalAuthenticatedData: _base64Encode(additionalAuthenticatedData),
  );
  final decryptResponse = await kmsApi.projects.locations.keyRings.cryptoKeys
      .decrypt(decryptRequest, keyPath);
  if (decryptResponse.plaintext == null) {
    return null;
  }
  return utf8.decode(base64.decode(decryptResponse.plaintext!));
}

/// Gets the current Google Cloud project's ID from the metadata service.
Future<String> get projectId => _metadataValue('project/project-id');

/// Gets the runtime service account email from the metadata service.
Future<String> get runtimeServiceAccountEmail =>
    _metadataValue('instance/service-accounts/default/email');

Future<String> _metadataValue(String path) async {
  final response = await get(
    Uri.parse('$_metadataBaseUrl/$path'),
    headers: _metadataHeaders,
  );
  final value = response.body.trim();
  if (response.statusCode != HttpStatus.ok || value.isEmpty) {
    throw StateError(
      'Failed to resolve Google Cloud metadata "$path": '
      '${response.statusCode} ${response.body}',
    );
  }

  return value;
}

Future<String> _keyPath(EncryptionKey key) async =>
    'projects/${await projectId}/locations/${key.region}/keyRings/${key.ring}/cryptoKeys/${key.name}';

String? _base64Encode(String? value) =>
    value == null ? null : base64.encode(utf8.encode(value));

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
