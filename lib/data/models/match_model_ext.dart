import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/match_model.dart';
import '../../domain/entities/match_entity.dart';

extension MatchModelToEntity on MatchModel {
  MatchEntity toEntity() => MatchEntity(
        id: id,
        users: users,
        timestamp: timestamp,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
      );
}

/// Factory din Map brut primit din datasource.
MatchModel matchModelFromMap(Map<String, dynamic> map, String id) =>
    MatchModel.fromMap(map, id);

/// Conversie entitate → Map pentru scriere în datasource.
Map<String, dynamic> matchEntityToMap(MatchEntity e) => {
      'users': e.users,
      if (e.timestamp != null)
        'timestamp': Timestamp.fromDate(e.timestamp!),
      if (e.lastMessage != null) 'lastMessage': e.lastMessage,
      if (e.lastMessageTime != null)
        'lastMessageTime': Timestamp.fromDate(e.lastMessageTime!),
    };
