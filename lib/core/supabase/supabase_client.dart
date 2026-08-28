import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'secure_local_storage.dart';

Future<void> initSupabase() async {
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: const SecureLocalStorage(),
      pkceAsyncStorage: SecureGotrueAsyncStorage(),
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
