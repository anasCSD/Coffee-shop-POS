import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    const definedUrl = String.fromEnvironment('SUPABASE_URL');
    const definedPublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    final config = await _loadConfig();
    final url = definedUrl.isNotEmpty
        ? definedUrl
        : config['SUPABASE_URL'] ?? config['NEXT_PUBLIC_SUPABASE_URL'] ?? '';
    final publishableKey = definedPublishableKey.isNotEmpty
        ? definedPublishableKey
        : config['SUPABASE_PUBLISHABLE_KEY'] ??
              config['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY'] ??
              '';

    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Supabase credentials are missing. '
        'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in config.json.',
      );
    }

    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }

  static Future<Map<String, String>> _loadConfig() async {
    final contents = await rootBundle.loadString('config.json');
    final config = <String, String>{};

    for (final line in contents.split(RegExp(r'\r?\n'))) {
      var entry = line.trim();
      if (entry.startsWith('//')) {
        entry = entry.substring(2).trimLeft();
      } else if (entry.startsWith('#')) {
        entry = entry.substring(1).trimLeft();
      }

      final separator = entry.indexOf('=');
      if (separator <= 0) continue;

      final key = entry.substring(0, separator).trim();
      var value = entry.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      config[key] = value;
    }

    return config;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
