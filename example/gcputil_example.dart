import 'package:gcputil/gcputil.dart';

Future<void> main() async {
  final project = await projectId;
  final serviceAccount = await runtimeServiceAccountEmail;

  print('Project: $project');
  print('Runtime service account: $serviceAccount');
}
