import 'dart:convert';

import 'package:googleapis/cloudtasks/v2.dart' as tasks;
import 'package:googleapis/run/v2.dart' as run;
import 'package:googleapis_auth/auth_io.dart';

import 'gcloud.dart';

/// Configuration for enqueuing a Google Cloud Run job through Cloud Tasks.
class CloudRunTaskConfig {
  /// Constructor.
  const CloudRunTaskConfig({
    required this.location,
    required this.queue,
    required this.job,
    required this.taskServiceAccountEmail,
    this.projectId,
  });

  /// The Google Cloud project id. Defaults to the runtime project id.
  final String? projectId;

  /// The Cloud Tasks and Cloud Run location.
  final String location;

  /// The Cloud Tasks queue name.
  final String queue;

  /// The Cloud Run job name.
  final String job;

  /// The service account email used by Cloud Tasks for the OAuth token.
  final String taskServiceAccountEmail;
}

/// Enqueues a Cloud Tasks HTTP task that invokes a Cloud Run job.
Future<void> enqueueCloudRunJobTask({
  required AuthClient client,
  required CloudRunTaskConfig config,
  required String taskId,
  int taskCount = 1,
  Map<String, String> env = const {},
}) async {
  final api = tasks.CloudTasksApi(client);
  final currentProjectId = config.projectId ?? await projectId;
  final parent =
      'projects/$currentProjectId/locations/${config.location}/queues/${config.queue}';
  final runJobUrl =
      'https://run.googleapis.com/v2/projects/$currentProjectId/locations/${config.location}/jobs/${config.job}:run';
  final runRequest = run.GoogleCloudRunV2RunJobRequest(
    overrides: run.GoogleCloudRunV2Overrides(
      taskCount: taskCount,
      containerOverrides: env.isEmpty
          ? null
          : [
              run.GoogleCloudRunV2ContainerOverride(
                env: [
                  for (final entry in env.entries)
                    run.GoogleCloudRunV2EnvVar(
                      name: entry.key,
                      value: entry.value,
                    ),
                ],
              ),
            ],
    ),
  );

  await api.projects.locations.queues.tasks.create(
    tasks.CreateTaskRequest(
      task: tasks.Task(
        name: '$parent/tasks/$taskId',
        httpRequest: tasks.HttpRequest(
          httpMethod: 'POST',
          url: runJobUrl,
          headers: {'Content-Type': 'application/json'},
          body: base64Url.encode(utf8.encode(jsonEncode(runRequest.toJson()))),
          oauthToken: tasks.OAuthToken(
            serviceAccountEmail: config.taskServiceAccountEmail,
            scope: tasks.CloudTasksApi.cloudPlatformScope,
          ),
        ),
      ),
    ),
    parent,
  );
}
