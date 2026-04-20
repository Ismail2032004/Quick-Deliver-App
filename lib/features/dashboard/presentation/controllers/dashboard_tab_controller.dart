import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardTabProvider = StateProvider.family<int, String>((ref, key) => 0);
