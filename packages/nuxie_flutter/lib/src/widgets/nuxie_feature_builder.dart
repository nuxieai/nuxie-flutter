import 'package:flutter/widgets.dart';
import '../../nuxie_flutter.dart';

/// Selects a globally scoped Feature from the native snapshot without querying.
class NuxieFeatureBuilder extends StatelessWidget {
  const NuxieFeatureBuilder({
    super.key,
    required this.client,
    required this.featureId,
    required this.builder,
  });
  final NuxieClient client;
  final String featureId;
  final Widget Function(BuildContext, FeatureAccess?, FeatureState) builder;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<NuxieFeatureSnapshot>(
        valueListenable: client.features,
        builder: (context, snapshot, _) =>
            builder(context, snapshot[featureId], snapshot.state),
      );
}
