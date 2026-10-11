// Collects the frame timings of integration_test/frame_timing_test.dart.
// On a real device, in a profile build (release test L4):
//
//     flutter drive --profile -d <device> \
//       --driver=test_driver/perf_driver.dart \
//       --target=integration_test/frame_timing_test.dart
//
// Writes build/integration_response_data.json and prints build and raster
// times per scene for the release issue.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) {
      return;
    }
    await writeResponseData(data);
    for (final MapEntry(key: scene, value: summary) in data.entries) {
      if (summary is! Map) {
        continue;
      }
      // ignore: avoid_print
      print(
        '$scene: build avg ${summary['average_frame_build_time_millis']} ms, '
        'p90 ${summary['90th_percentile_frame_build_time_millis']} ms; '
        'raster avg ${summary['average_frame_rasterizer_time_millis']} ms, '
        'p90 ${summary['90th_percentile_frame_rasterizer_time_millis']} ms, '
        'p99 ${summary['99th_percentile_frame_rasterizer_time_millis']} ms; '
        'missed ${summary['missed_frame_rasterizer_budget_count']} of '
        '${summary['frame_count']}',
      );
    }
  },
);
