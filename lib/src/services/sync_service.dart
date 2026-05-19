import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'firestore_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref.read));

class _QueuedOp {
  final String id;
  final String uid;
  final String op; // 'set'|'update'|'delete'
  final String collection;
  final String docId;
  final Map<String, dynamic>? data;

  _QueuedOp({required this.id, required this.uid, required this.op, required this.collection, required this.docId, this.data});

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'op': op,
        'collection': collection,
        'docId': docId,
        'data': data,
      };

  factory _QueuedOp.fromJson(Map<String, dynamic> m) => _QueuedOp(
        id: m['id'] as String,
        uid: m['uid'] as String,
        op: m['op'] as String,
        collection: m['collection'] as String,
        docId: m['docId'] as String,
        data: (m['data'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v)),
      );
}

class SyncService {
  final Reader _read;
  final List<_QueuedOp> _queue = [];
  late final File _queueFile;

  static const _allowedCollections = {'transactions', 'categories', 'budgets'};
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _running = false;

  SyncService(this._read) {
    _init();
  }

  Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    _queueFile = File('${dir.path}/sync_queue.json');
    await _loadQueue();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((event) {
      if (event != ConnectivityResult.none) {
        _processQueueIfNeeded();
      }
    });
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
  }

  Future<void> _loadQueue() async {
    try {
      if (await _queueFile.exists()) {
        final content = await _queueFile.readAsString();
        if (content.isNotEmpty) {
          final list = jsonDecode(content) as List<dynamic>;
          _queue.clear();
          _queue.addAll(list.map((e) => _QueuedOp.fromJson(e as Map<String, dynamic>)));
        }
      }
    } catch (_) {
      if (kDebugMode) print('Failed to load sync queue');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final json = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await _queueFile.writeAsString(json, flush: true);
    } catch (_) {
      if (kDebugMode) print('Failed to save sync queue');
    }
  }

  Future<void> enqueueSet(String uid, String collection, String docId, Map<String, dynamic> data) async {
    if (!_allowedCollections.contains(collection)) throw ArgumentError('Collection not allowed: $collection');
    final op = _QueuedOp(id: const Uuid().v4(), uid: uid, op: 'set', collection: collection, docId: docId, data: data);
    _queue.add(op);
    await _saveQueue();
    _processQueueIfNeeded();
  }

  Future<void> enqueueUpdate(String uid, String collection, String docId, Map<String, dynamic> data) async {
    if (!_allowedCollections.contains(collection)) throw ArgumentError('Collection not allowed: $collection');
    final op = _QueuedOp(id: const Uuid().v4(), uid: uid, op: 'update', collection: collection, docId: docId, data: data);
    _queue.add(op);
    await _saveQueue();
    _processQueueIfNeeded();
  }

  Future<void> enqueueDelete(String uid, String collection, String docId) async {
    if (!_allowedCollections.contains(collection)) throw ArgumentError('Collection not allowed: $collection');
    final op = _QueuedOp(id: const Uuid().v4(), uid: uid, op: 'delete', collection: collection, docId: docId);
    _queue.add(op);
    await _saveQueue();
    _processQueueIfNeeded();
  }

  Future<void> _processQueueIfNeeded() async {
    if (_running) return;
    _running = true;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) return;
      if (_queue.isEmpty) return;

      final fs = _read(firestoreServiceProvider);
      // Attempt to flush
      final remaining = <_QueuedOp>[];
      for (final op in List<_QueuedOp>.from(_queue)) {
        try {
          if (op.op == 'set') {
            await fs.setDocument(op.uid, op.collection, op.docId, op.data ?? {});
          } else if (op.op == 'update') {
            await fs.updateDocument(op.uid, op.collection, op.docId, op.data ?? {});
          } else if (op.op == 'delete') {
            await fs.deleteDocument(op.uid, op.collection, op.docId);
          }
        } catch (_) {
          remaining.add(op);
          if (kDebugMode) print('Sync op failed, will retry: ${op.id}');
        }
      }
      _queue
        ..clear()
        ..addAll(remaining);
      await _saveQueue();
    } finally {
      _running = false;
    }
  }
}
