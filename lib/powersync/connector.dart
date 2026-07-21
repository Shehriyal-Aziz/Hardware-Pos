import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart';

class HardwarePosConnector extends PowerSyncBackendConnector {
  final PowerSyncDatabase db;

  HardwarePosConnector(this.db);

  // Supabase project details. The publishable/anon key is safe to embed
  // in the client app — it only allows what your RLS policies permit
  // (currently RLS is off for development, so this key can read/write
  // everything for now; lock this down before shipping to a real client).
  static const _supabaseUrl = 'https://kbtpmlxsqdewvoaydmug.supabase.co';
  static const _supabaseAnonKey =
      'sb_publishable_EH8aNuYd67gndfxDlP2mUg__kTsrtze';

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Development token — expires after 12 hours. For production, this
    // must be replaced with a real auth flow (e.g. Supabase Auth) that
    // fetches a fresh token automatically instead of a hardcoded one.
    return PowerSyncCredentials(
      endpoint: 'https://6a5df9b07f33bac37ef868c0.powersync.journeyapps.com',
      token:
          'eyJhbGciOiJSUzI1NiIsImtpZCI6InBvd2Vyc3luYy1kZXYtMzIyM2Q0ZTMifQ.eyJzdWIiOiJ0ZXN0LXVzZXIiLCJpYXQiOjE3ODQ2MTM1ODQsImlzcyI6Imh0dHBzOi8vcG93ZXJzeW5jLWFwaS5qb3VybmV5YXBwcy5jb20iLCJhdWQiOiJodHRwczovLzZhNWRmOWIwN2YzM2JhYzM3ZWY4NjhjMC5wb3dlcnN5bmMuam91cm5leWFwcHMuY29tIiwiZXhwIjoxNzg0NjU2Nzg0fQ.UDN8WbFTKPBlCIqfGpQiSyKo8ItUYhjjtB9Vi8Yp4tSJVoQFHI7q5mSqVrfB1VTAQbXpUQ2V8l1vHfRZUo7rnYlqad0GXVQAHyNgaZhCU7M5j5elHp5-K2ljRAzDLtBBxRuHHVPyRO36IVcy7BiyTuoZx7aYOCIiG_KI1aud5Hdc14RdvMZ3XhlAfoGboDH0KcL-KHo0KcfUFbxHVZlg07ozI6gFEDDbb_FbrjdysC-pDODu0CrMz86KAiMoaRGv5vo0pcOP6FQpG419drNK9u5p2gQVYXcKabMzX5kwGp-rljQEf33aUZFYiqLUhZ-I5yh-D8VQpXCsBvtNs5ePaA',
    );
  }

  Map<String, String> get _headers => {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      };

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (final op in transaction.crud) {
        final tableUrl = Uri.parse('$_supabaseUrl/rest/v1/${op.table}');

        switch (op.op) {
          case UpdateType.put:
            // Insert or replace — PostgREST upsert via Prefer header.
            final row = {'id': op.id, ...?op.opData};
            final res = await http.post(
              tableUrl,
              headers: {
                ..._headers,
                'Prefer': 'resolution=merge-duplicates,return=minimal',
              },
              body: jsonEncode(row),
            );
            if (res.statusCode >= 300) {
              throw Exception(
                  'Supabase insert failed (${res.statusCode}): ${res.body}');
            }
            break;

          case UpdateType.patch:
            final res = await http.patch(
              tableUrl.replace(queryParameters: {'id': 'eq.${op.id}'}),
              headers: _headers,
              body: jsonEncode(op.opData),
            );
            if (res.statusCode >= 300) {
              throw Exception(
                  'Supabase update failed (${res.statusCode}): ${res.body}');
            }
            break;

          case UpdateType.delete:
            final res = await http.delete(
              tableUrl.replace(queryParameters: {'id': 'eq.${op.id}'}),
              headers: _headers,
            );
            if (res.statusCode >= 300) {
              throw Exception(
                  'Supabase delete failed (${res.statusCode}): ${res.body}');
            }
            break;
        }
      }
      await transaction.complete();
    } catch (e) {
      // Leave the transaction for retry — PowerSync will call
      // uploadData again automatically (e.g. once connectivity returns).
      rethrow;
    }
  }
}