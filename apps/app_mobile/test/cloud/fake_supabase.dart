/// In-memory Supabase stand-in for the app tests: GoTrue (password sign-in,
/// phone OTP, sign-out), PostgREST (eq filters, upsert on conflict),
/// the WhatsApp RPCs and the member-invite RPCs, all behind `package:http`'s
/// `MockClient`. Enough for the linker rules, the sign-in gate, the provider
/// switch, the config form and invites.
library;

import 'dart:convert';

import 'package:ampdent_data/ampdent_data.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// One observed request.
class FakeCall {
  FakeCall(this.method, this.path, this.query, this.body);

  final String method;
  final String path;
  final Map<String, String> query;
  final Object? body;

  /// Body rows (a single object is wrapped).
  List<Map<String, Object?>> get rows => [
    for (final r in body is List ? body as List : [body])
      if (r is Map) r.cast<String, Object?>(),
  ];

  @override
  String toString() => '$method $path $query';
}

/// The fake project.
class FakeSupabase {
  FakeSupabase({
    this.userId = 'user-1',
    this.email = 'dr@example.com',
    this.password = 'correct-horse-battery',
    this.phone = '+919000000002',
    this.otp = '123456',
  });

  final String userId;
  final String email;
  final String password;
  final String phone;
  final String otp;

  /// Server tables by name.
  final Map<String, List<Map<String, Object?>>> tables = {};

  /// Every REST request seen.
  final List<FakeCall> calls = [];

  /// RPC calls as (name, params).
  final List<(String, Map<String, Object?>)> rpcCalls = [];

  /// Access tokens handed to `set_whatsapp_config`.
  final List<String> receivedTokens = [];

  /// Response of `get_whatsapp_status`.
  Map<String, Object?> whatsappStatus = {
    'configured': false,
    'enabled': false,
    'phoneNumberId': null,
    'wabaId': null,
    'displayPhone': null,
    'updatedAt': null,
    'queuedCount': 0,
    'failedLast24h': 0,
  };

  /// When set, every REST and RPC request fails with this status.
  int? failAllWith;

  /// Codes `create_member_invite` hands out, in order (then cycling).
  static const List<String> inviteCodes = [
    'ABCDEFGH',
    'JKMNPQRS',
    'TUVWXYZ2',
    'A2B3C4D5',
  ];

  bool signedIn = false;
  int _micros = DateTime.utc(2026, 10, 20, 8).microsecondsSinceEpoch;
  int _inviteSeq = 0;

  /// The fake server clock (monotonic, advanced by [nextTimestamp]).
  DateTime get now => DateTime.fromMicrosecondsSinceEpoch(_micros, isUtc: true);

  /// A client over this fake; auto refresh off so tests leave no timers.
  SupabaseClient client() => SupabaseClient(
    'http://localhost:54321',
    'test-anon-key',
    httpClient: MockClient(handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  /// Rows of [table].
  List<Map<String, Object?>> rows(String table) => tables[table] ?? const [];

  /// Row by id.
  Map<String, Object?>? row(String table, String id) =>
      rows(table)
          .cast<Map<String, Object?>?>()
          .firstWhere((r) => r!['id'] == id, orElse: () => null);

  /// Requests to [path] (a table name or `rpc/<fn>`).
  List<FakeCall> callsTo(String path, {String? method}) => [
    for (final c in calls)
      if (c.path == path && (method == null || c.method == method)) c,
  ];

  /// Server timestamp text, monotonic.
  String nextTimestamp() {
    _micros += 1000;
    final iso = DateTime.fromMicrosecondsSinceEpoch(
      _micros,
      isUtc: true,
    ).toIso8601String();
    return '${iso.substring(0, iso.length - 1)}+00:00';
  }

  /// Inserts a server row, assigning `updated_at` when missing.
  Map<String, Object?> seed(String table, Map<String, Object?> row) {
    final stored = {...row};
    stored['updated_at'] ??= nextTimestamp();
    stored['created_at'] ??= stored['updated_at'];
    (tables[table] ??= []).add(stored);
    return stored;
  }

  /// Marks every live invite as expired (the clock moved past 72 h).
  void expireInvites() {
    for (final r in rows('member_invites')) {
      if (r['claimed_at'] == null) {
        r['expires_at'] = now
            .subtract(const Duration(minutes: 1))
            .toIso8601String();
      }
    }
  }

  /// Copies every sync table of [db] to the server as PostgREST would
  /// return it; `clinic_members.user_id` comes from [memberUserIds].
  Future<void> seedFromDatabase(
    AppDatabase db, {
    Map<String, String> memberUserIds = const {},
  }) async {
    for (final table in syncTables) {
      final info = db.allTables.firstWhere(
        (t) => t.actualTableName == table.name,
      );
      final codec = SyncRowCodec(info, jsonTextColumns: table.jsonTextColumns);
      final local = await db
          .customSelect('SELECT * FROM "${table.name}"')
          .get();
      for (final r in local) {
        final server = codec.toServer(r.data);
        if (table.name == 'clinic_members') {
          server['user_id'] = memberUserIds['${server['id']}'];
        }
        seed(table.name, server);
      }
    }
  }

  Map<String, Object?> _session() => {
    'access_token': 'fake-access-token-$userId',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'fake-refresh',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'phone': phone.replaceAll('+', ''),
      'app_metadata': {'provider': 'email'},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-10-01T00:00:00Z',
    },
  };

  http.Response _json(Object? body, [int status = 200]) => http.Response(
    body == null ? '' : jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response _authError(String msg, int status) =>
      _json({'code': status, 'error_code': 'invalid', 'msg': msg}, status);

  http.Response _pgError(int status, String message) => _json({
    'message': message,
    'code': null,
    'details': null,
    'hint': null,
  }, status);

  Future<http.Response> handle(http.Request req) async {
    final segments = req.url.pathSegments;
    Object? body;
    if (req.body.isNotEmpty) {
      try {
        body = jsonDecode(req.body);
      } on FormatException {
        body = req.body;
      }
    }
    final http.Response res;
    if (segments.length >= 2 && segments[0] == 'auth') {
      res = _auth(segments.sublist(2).join('/'), req, body);
    } else if (segments.length >= 2 && segments[0] == 'rest') {
      final path = segments.sublist(2).join('/');
      calls.add(FakeCall(req.method, path, req.url.queryParameters, body));
      final fail = failAllWith;
      if (fail != null) {
        res = _pgError(fail, 'injected failure');
      } else if (path.startsWith('rpc/')) {
        res = _rpc(path.substring(4), body);
      } else {
        res = switch (req.method) {
          'GET' => _select(path, req.url.queryParameters),
          'POST' => _upsert(path, req, body is List ? body : [body]),
          _ => _pgError(405, 'unsupported'),
        };
      }
    } else {
      res = _pgError(404, 'unknown ${req.url.path}');
    }
    return http.Response(
      res.body,
      res.statusCode,
      headers: res.headers,
      request: req,
    );
  }

  http.Response _auth(String path, http.Request req, Object? body) {
    final map = body is Map ? body.cast<String, Object?>() : const {};
    switch (path) {
      case 'token':
        if (req.url.queryParameters['grant_type'] != 'password') {
          return _authError('unsupported grant', 400);
        }
        if (map['email'] == email && map['password'] == password) {
          signedIn = true;
          return _json(_session());
        }
        return _authError('Invalid login credentials', 400);
      case 'otp':
        return _json(<String, Object?>{});
      case 'verify':
        if (map['token'] == otp) {
          signedIn = true;
          return _json(_session());
        }
        return _authError('Token has expired or is invalid', 403);
      case 'logout':
        signedIn = false;
        return http.Response('', 204);
      default:
        return _authError('unknown auth path $path', 404);
    }
  }

  http.Response _rpc(String fn, Object? body) {
    final params = body is Map
        ? body.cast<String, Object?>()
        : <String, Object?>{};
    rpcCalls.add((fn, params));
    switch (fn) {
      case 'get_whatsapp_status':
        return _json(whatsappStatus);
      case 'set_whatsapp_config':
        receivedTokens.add('${params['p_access_token']}');
        whatsappStatus = {
          ...whatsappStatus,
          'configured': true,
          'phoneNumberId': params['p_phone_number_id'],
          'wabaId': params['p_waba_id'],
          'displayPhone': params['p_display_phone'],
          'updatedAt': nextTimestamp(),
        };
        return http.Response('', 204);
      case 'set_whatsapp_enabled':
        whatsappStatus = {
          ...whatsappStatus,
          'enabled': params['p_enabled'] == true,
        };
        return http.Response('', 204);
      case 'create_member_invite':
        return _createMemberInvite('${params['p_member']}');
      case 'claim_member_invite':
        return _claimMemberInvite('${params['p_code']}');
      case 'unlink_member':
        return _unlinkMember('${params['p_member']}');
      default:
        return _pgError(404, 'function $fn not found');
    }
  }

  bool _isOwnerOf(String clinicId) => rows('clinic_members').any(
    (m) =>
        m['clinic_id'] == clinicId &&
        m['user_id'] == userId &&
        m['role'] == 'ownerDentist',
  );

  /// Mirrors `app.create_member_invite` (migration 0010).
  http.Response _createMemberInvite(String memberId) {
    if (!signedIn) return _pgError(401, 'sign in to create an invite');
    final member = row('clinic_members', memberId);
    if (member == null || !_isOwnerOf('${member['clinic_id']}')) {
      return _pgError(403, 'only the clinic owner may invite member $memberId');
    }
    if (member['is_active'] == false) {
      return _pgError(400, 'member $memberId is deactivated');
    }
    if (member['user_id'] != null) {
      return _pgError(
        400,
        'member $memberId is already signed in with an account',
      );
    }
    for (final r in rows('member_invites')) {
      if (r['member_id'] == memberId && r['claimed_at'] == null) {
        r['expires_at'] = now.toIso8601String();
      }
    }
    final code = inviteCodes[_inviteSeq++ % inviteCodes.length];
    seed('member_invites', {
      'id': 'invite-$_inviteSeq',
      'clinic_id': member['clinic_id'],
      'member_id': memberId,
      'code': code,
      'created_by': userId,
      'expires_at': now.add(const Duration(hours: 72)).toIso8601String(),
      'claimed_by': null,
      'claimed_at': null,
    });
    return _json(code);
  }

  /// Mirrors `app.unlink_member` (migration 0012).
  http.Response _unlinkMember(String memberId) {
    if (!signedIn) return _pgError(401, 'sign in to unlink a member');
    final member = row('clinic_members', memberId);
    if (member == null || !_isOwnerOf('${member['clinic_id']}')) {
      return _pgError(403, 'only the clinic owner may unlink member $memberId');
    }
    if (member['user_id'] == null) {
      return _pgError(400, 'member $memberId has no account to unlink');
    }
    if (member['user_id'] == userId) {
      return _pgError(400, 'you cannot unlink your own account');
    }
    member['user_id'] = null;
    member['updated_at'] = nextTimestamp();
    for (final r in rows('member_invites')) {
      if (r['member_id'] == memberId && r['claimed_at'] == null) {
        r['expires_at'] = now.toIso8601String();
      }
    }
    return _json(true);
  }

  /// Mirrors `app.claim_member_invite` (migration 0010).
  http.Response _claimMemberInvite(String raw) {
    if (!signedIn) return _pgError(401, 'sign in to use an invite code');
    final code = raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[A-HJKMNP-Z2-9]{8}$').hasMatch(code)) {
      return _pgError(400, 'invite code not recognised');
    }
    final invite = rows('member_invites')
        .cast<Map<String, Object?>?>()
        .firstWhere((r) => r!['code'] == code, orElse: () => null);
    if (invite == null) return _pgError(400, 'invite code not recognised');
    if (invite['claimed_at'] != null) {
      return _pgError(400, 'invite code already used');
    }
    final expires = DateTime.parse('${invite['expires_at']}');
    if (!expires.isAfter(now)) {
      return _pgError(
        400,
        'invite code expired; ask the clinic owner for a new one',
      );
    }
    final member = row('clinic_members', '${invite['member_id']}');
    if (member == null || member['is_active'] == false) {
      return _pgError(400, 'the invited member row is no longer active');
    }
    if (member['user_id'] != null && member['user_id'] != userId) {
      return _pgError(403, 'this invite belongs to another account');
    }
    final clinicId = member['clinic_id'];
    if (rows('clinic_members').any(
      (m) =>
          m['clinic_id'] == clinicId &&
          m['user_id'] == userId &&
          m['id'] != member['id'],
    )) {
      return _pgError(403, 'you are already a member of this clinic');
    }
    member['user_id'] = userId;
    member['updated_at'] = nextTimestamp();
    invite['claimed_by'] = userId;
    invite['claimed_at'] = nextTimestamp();
    return _json(clinicId);
  }

  http.Response _select(String table, Map<String, String> query) {
    var result = rows(table);
    for (final e in query.entries) {
      if (!e.value.startsWith('eq.')) continue;
      final want = e.value.substring(3);
      result = [
        for (final r in result)
          if ('${r[e.key]}' == want) r,
      ];
    }
    return _json(result);
  }

  http.Response _upsert(String table, http.Request req, List body) {
    final keys = (req.url.queryParameters['on_conflict'] ?? 'id').split(',');
    final store = tables[table] ??= [];
    for (final raw in body) {
      final row = (raw as Map).cast<String, Object?>();
      final existing = store.cast<Map<String, Object?>?>().firstWhere(
        (r) => keys.every((k) => r![k] == row[k]),
        orElse: () => null,
      );
      if (existing == null) {
        if (table == 'devices' &&
            row['is_primary'] == true &&
            store.any(
              (r) =>
                  r['clinic_id'] == row['clinic_id'] && r['is_primary'] == true,
            )) {
          return _pgError(409, 'duplicate key devices_one_primary_per_clinic');
        }
        seed(table, row);
      } else {
        existing.addAll(row);
        existing['updated_at'] = nextTimestamp();
      }
    }
    return http.Response('', 201);
  }
}
