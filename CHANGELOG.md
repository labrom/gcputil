## 0.3.0

- Cache project ID and runtime service account metadata for the lifetime of the
  process, while allowing retries after metadata request failures.

## 0.2.0

- Add optional authenticated clients to Cloud KMS encryption and decryption
  helpers.
- Add optional additional authenticated data support to Cloud KMS encryption
  and decryption helpers.
- Simplify Cloud KMS request construction.

## 0.1.0

- Initial release.
- Add Google Cloud metadata helpers for project ID and runtime service account.
- Add Secret Manager lookup with environment-variable fallback.
- Add Cloud KMS encryption and decryption helpers.
- Add Google APIs service-account client helper.
- Add Cloud Tasks helper for invoking Cloud Run jobs.
