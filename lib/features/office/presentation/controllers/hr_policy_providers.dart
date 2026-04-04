import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hr_policy_repository.dart';
import '../../data/models/hr_policy_model.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

final hrPolicyRepositoryProvider =
    Provider<HRPolicyRepository>((_) => HRPolicyRepository());

/// Reactive HR policy for the current user's office.
final hrPolicyProvider = StreamProvider<HRPolicyModel>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value(HRPolicyModel.defaults());
      return ref
          .watch(hrPolicyRepositoryProvider)
          .watchPolicy(user.officeId);
    },
    loading: () => Stream.value(HRPolicyModel.defaults()),
    error: (_, _) => Stream.value(HRPolicyModel.defaults()),
  );
});
