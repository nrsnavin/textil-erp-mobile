import 'dart:convert';

/// Represents a single offline mutation queued for server sync.
///
/// Each mutation captures an API call that was made while offline.
/// The [clientId] is a UUID generated on the client that the server
/// uses for idempotent deduplication — if a mutation is replayed
/// (e.g. after crash during sync), the server returns the cached
/// result instead of executing the operation twice.
enum MutationStatus {
  pending,   // Waiting to be synced
  syncing,   // Currently being sent to server
  synced,    // Server acknowledged
  failed,    // Server returned an error
}

class Mutation {
  final int? id;            // SQLite auto-increment PK
  final String clientId;    // Client-generated UUID (idempotency key)
  final String endpoint;    // e.g. "/api/v1/buyers"
  final String method;      // POST | PATCH | PUT | DELETE
  final Map<String, dynamic>? body;
  final MutationStatus status;
  final int retryCount;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? syncedAt;

  Mutation({
    this.id,
    required this.clientId,
    required this.endpoint,
    required this.method,
    this.body,
    this.status = MutationStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.syncedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Mutation copyWith({
    int? id,
    String? clientId,
    String? endpoint,
    String? method,
    Map<String, dynamic>? body,
    MutationStatus? status,
    int? retryCount,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return Mutation(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      body: body ?? this.body,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_id': clientId,
      'endpoint': endpoint,
      'method': method,
      'body': body != null ? jsonEncode(body) : null,
      'status': status.index,
      'retry_count': retryCount,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory Mutation.fromMap(Map<String, dynamic> map) {
    return Mutation(
      id: map['id'] as int?,
      clientId: map['client_id'] as String,
      endpoint: map['endpoint'] as String,
      method: map['method'] as String,
      body: map['body'] != null
          ? jsonDecode(map['body'] as String) as Map<String, dynamic>
          : null,
      status: MutationStatus.values[map['status'] as int],
      retryCount: map['retry_count'] as int? ?? 0,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
    );
  }

  /// Serialize for the server's /api/v1/sync/push endpoint.
  Map<String, dynamic> toSyncPayload() {
    return {
      'clientId': clientId,
      'endpoint': endpoint,
      'method': method,
      if (body != null) 'body': body,
    };
  }

  @override
  String toString() =>
      'Mutation(id=$id, clientId=$clientId, $method $endpoint, status=$status)';
}
