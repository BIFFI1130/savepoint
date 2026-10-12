import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/steam_import_repository.dart';

final steamImportRepositoryProvider = Provider<SteamImportRepository>((ref) {
  return SupabaseSteamImportRepository();
});
