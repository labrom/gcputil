# gcputil

Shared Dart utilities for services running on Google Cloud.

Current helpers cover:

- Google Cloud project and runtime service account metadata.
- Secret Manager lookup with environment-variable fallback.
- Cloud KMS encryption/decryption.
- Google APIs service-account clients backed by Secret Manager keys.
- Enqueuing Cloud Tasks requests that invoke Cloud Run jobs.

## Usage

```dart
import 'package:gcputil/gcputil.dart';

Future<void> main() async {
  final project = await projectId;
  final apiKey = await secret('my-api-key');

  final key = EncryptionKey(
    name: 'token-key',
    ring: 'application',
    region: 'us-central1',
  );

  final cipher = await encrypt(apiKey, key);
  final plaintext = await decrypt(cipher!, key);

  print('Project: $project');
  print('Recovered secret: $plaintext');
}
```

The helpers that use Google Cloud metadata credentials are intended for
workloads running on Google Cloud, such as Cloud Run, Compute Engine, and
environments with Application Default Credentials.
