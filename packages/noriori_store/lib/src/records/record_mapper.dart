import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';

// DB 행과 도메인 타입의 변환. 열을 더할 때 고칠 곳은 여기 하나다.

RideLeg legFromRow(RideLegRow row) => RideLeg(
      seq: row.seq,
      lineId: LineId(row.lineId),
      routeId: RouteId(row.routeId),
      fromNode: NodeId(row.fromNode),
      toNode: NodeId(row.toNode),
      direction: row.direction,
      resolveAsOf: row.resolveAsOf,
      resolveUnknown: row.resolveUnknown,
      lineLabel: row.lineLabel,
      fromLabel: row.fromLabel,
      toLabel: row.toLabel,
    );

Ride rideFromRow(RideRow row, List<RideLegRow> legs) => Ride(
      rideId: RideId(row.id),
      legs: [for (final leg in legs) legFromRow(leg)],
      datasetVersion: row.datasetVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      deviceId: row.deviceId,
      tripId: row.tripId == null ? null : TripId(row.tripId!),
      dateInput: row.dateInput,
      times: row.times,
      trainName: row.trainName,
      carNo: row.carNo,
      note: row.note,
      serviceId: row.serviceId == null ? null : ServiceId(row.serviceId!),
      transferNodes: [
        for (final node in jsonDecode(row.transferNodes) as List<Object?>)
          NodeId(node as String),
      ],
      fromAlighted: row.fromAlighted,
      toAlighted: row.toAlighted,
      importSource: row.importSource,
      importRaw: row.importRaw,
    );

RideTableCompanion rideToRow(Ride ride) => RideTableCompanion.insert(
      id: ride.id,
      createdAt: ride.createdAt,
      updatedAt: ride.updatedAt,
      deletedAt: Value(ride.deletedAt),
      deviceId: ride.deviceId,
      tripId: Value(ride.tripId),
      dateInput: Value(ride.dateInput),
      times: Value(ride.times),
      trainName: Value(ride.trainName),
      carNo: Value(ride.carNo),
      note: Value(ride.note),
      serviceId: Value(ride.serviceId),
      transferNodes: Value(jsonEncode(ride.transferNodes)),
      fromAlighted: ride.fromAlighted,
      toAlighted: ride.toAlighted,
      datasetVersion: ride.datasetVersion,
      importSource: Value(ride.importSource),
      importRaw: Value(ride.importRaw),
    );

RideLegTableCompanion legToRow(RideId ride, RideLeg leg) => RideLegTableCompanion.insert(
      rideId: ride,
      seq: leg.seq,
      lineId: leg.lineId,
      routeId: leg.routeId,
      fromNode: leg.fromNode,
      toNode: leg.toNode,
      direction: Value(leg.direction),
      resolveAsOf: Value(leg.resolveAsOf),
      resolveUnknown: leg.resolveUnknown,
      lineLabel: leg.lineLabel,
      fromLabel: leg.fromLabel,
      toLabel: leg.toLabel,
    );

Visit visitFromRow(VisitRow row) => Visit(
      visitId: VisitId(row.id),
      nodeId: NodeId(row.nodeId),
      nodeLabel: row.nodeLabel,
      nodeExplicit: row.nodeExplicit,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      deviceId: row.deviceId,
      dateInput: row.dateInput,
      note: row.note,
    );

VisitTableCompanion visitToRow(Visit visit) => VisitTableCompanion.insert(
      id: visit.id,
      createdAt: visit.createdAt,
      updatedAt: visit.updatedAt,
      deletedAt: Value(visit.deletedAt),
      deviceId: visit.deviceId,
      nodeId: visit.nodeId,
      nodeLabel: visit.nodeLabel,
      nodeExplicit: visit.nodeExplicit,
      dateInput: Value(visit.dateInput),
      note: Value(visit.note),
    );

Trip tripFromRow(TripRow row) => Trip(
      tripId: TripId(row.id),
      title: row.title,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      deviceId: row.deviceId,
    );

TripTableCompanion tripToRow(Trip trip) => TripTableCompanion.insert(
      id: trip.id,
      createdAt: trip.createdAt,
      updatedAt: trip.updatedAt,
      deletedAt: Value(trip.deletedAt),
      deviceId: trip.deviceId,
      title: trip.title,
      note: Value(trip.note),
    );

ChangeNote noteFromRow(ChangeReportRow row) => ChangeNote(
      noteId: row.id,
      edition: row.edition,
      body: row.body,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      deviceId: row.deviceId,
    );

ChangeReportRow noteToRow(ChangeNote note) => ChangeReportRow(
      id: note.id,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      deletedAt: note.deletedAt,
      deviceId: note.deviceId,
      edition: note.edition,
      body: note.body,
    );
