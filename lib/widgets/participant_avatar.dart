// lib/widgets/participant_avatar.dart
// Widget avatar berbentuk lingkaran dengan inisial nama peserta.
// Digunakan di banyak tempat: waiting room, item selection, summary.

import 'package:flutter/material.dart';
import '../models/models.dart';

class ParticipantAvatar extends StatelessWidget {
  final Participant participant;
  final double size;          // Ukuran diameter lingkaran
  final bool isSelected;      // Apakah sedang terpilih? (untuk item assignment)
  final bool showName;        // Tampilkan nama di bawah avatar?
  final VoidCallback? onTap;  // Callback saat di-tap

  const ParticipantAvatar({
    super.key,
    required this.participant,
    this.size = 48,
    this.isSelected = true,   // Default: aktif (berwarna)
    this.showName = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Kalau tidak terpilih, warna jadi abu-abu pucat
    final color = isSelected ? participant.color : const Color(0xFFE5E5EA);
    final textColor = isSelected ? Colors.white : const Color(0xFFC7C7CC);

    Widget avatar = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            participant.initial,
            style: TextStyle(
              color: textColor,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );

    // Kalau ada tanda centang (selected), tambahkan badge kecil
    if (isSelected && onTap != null) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.35,
              height: size * 0.35,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: participant.color, width: 1.5),
              ),
              child: Icon(
                Icons.check,
                size: size * 0.22,
                color: participant.color,
              ),
            ),
          ),
        ],
      );
    }

    // Kalau showName aktif, tampilkan nama di bawah
    if (showName) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 4),
          SizedBox(
            width: size + 8,
            child: Text(
              participant.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size * 0.25,
                color: const Color(0xFF1C1C1E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}

// ─── Row of Avatars ──────────────────────────────────────────
// Widget untuk menampilkan banyak avatar dalam satu baris.
// Digunakan di item list screen.
class ParticipantAvatarRow extends StatelessWidget {
  final List<Participant> participants;
  final Set<String> selectedIds;  // ID yang sedang terpilih
  final double size;
  final double spacing;
  final Function(String participantId)? onToggle;  // Callback toggle

  const ParticipantAvatarRow({
    super.key,
    required this.participants,
    required this.selectedIds,
    this.size = 32,
    this.spacing = 6,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: participants.asMap().entries.map((entry) {
        final index = entry.key;
        final participant = entry.value;
        final isSelected = selectedIds.contains(participant.id);

        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 0 : spacing,
          ),
          child: ParticipantAvatar(
            participant: participant,
            size: size,
            isSelected: isSelected,
            onTap: onToggle != null
                ? () => onToggle!(participant.id)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
