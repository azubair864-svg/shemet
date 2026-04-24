import 'package:flutter/material.dart';

class PartyRoomSeatSimple extends StatelessWidget {
  final bool isOccupied;
  final bool isHost;
  final String? userPhoto;
  final VoidCallback? onTap;

  const PartyRoomSeatSimple({
    super.key,
    required this.isOccupied,
    this.isHost = false,
    this.userPhoto,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isOccupied
              ? const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isOccupied ? null : Colors.grey.shade800.withOpacity(0.3),
          boxShadow: isOccupied
              ? [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ]
              : null,
        ),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isOccupied ? Colors.purple.shade700 : Colors.grey.shade700.withOpacity(0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: isOccupied
                ? (userPhoto != null && userPhoto!.isNotEmpty
                ? Image.network(
              userPhoto!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            )
                : const Center(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 32,
              ),
            ))
                : Center(
              child: Icon(
                Icons.add,
                color: Colors.white.withOpacity(0.3),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}