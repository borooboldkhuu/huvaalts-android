import 'dart:typed_data';

import '../entities/dispute.dart';
import '../entities/dispute_category.dart';

abstract interface class DisputeRepository {
  /// The most recent dispute raised on this booking, if any —
  /// `disputes_one_open_per_booking_idx` (0010) only limits *open*
  /// disputes to one at a time, so a booking could in principle have an
  /// older resolved/rejected one too; this returns the newest either way,
  /// which is what a "is there a dispute on this booking" UI needs.
  Future<Dispute?> getLatestDisputeForBooking(String bookingId);

  Future<Dispute> submitDispute({
    required String bookingId,
    required DisputeCategory category,
    required String description,
    required List<(Uint8List bytes, String fileExtension)> evidence,
  });

  Future<String> signedEvidenceUrl(String path);
}
