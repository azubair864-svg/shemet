import 'package:flutter/material.dart';
import 'party_room_seat.dart';
import '../../models/seat_model.dart';

class PartyRoomSeatGrid extends StatelessWidget {
  final String roomId;
  final List<String> participants;
  final Map<String, int> seatContributions;
  final int maxSeats;
  final String currentUserId;
  final String hostId;
  final Function(int) onSeatTap;
  final bool showDetails;

  const PartyRoomSeatGrid({
    super.key,
    required this.roomId,
    required this.participants,
    required this.seatContributions,
    required this.maxSeats,
    required this.currentUserId,
    required this.hostId,
    required this.onSeatTap,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: showDetails ? 4 : 3,
          mainAxisSpacing: showDetails ? 20 : 24,
          crossAxisSpacing: showDetails ? 16 : 24,
          childAspectRatio: showDetails ? 0.65 : 1.0,
        ),
        itemCount: maxSeats,
        itemBuilder: (context, index) {
          final isOccupied = index < participants.length;
          final userId = isOccupied ? participants[index] : null;
          final isHost = userId == hostId;
          final coins = seatContributions[userId] ?? 0;

          final seat = SeatModel(
            index: index,
            userId: userId,
            isLocked: false, // Default since we use legacy list here
          );

          return PartyRoomSeat(
            seat: seat,
            isHost: isHost,
            coins: coins,
            showDetails: showDetails,
            onTap: () => onSeatTap(index),
          );
        },
      ),
    );
  }
}
