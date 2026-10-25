import 'package:flutter/material.dart';

import '../../../models/song_filter.dart';

/// Dropdown ringkas untuk memilih jenis lagu: Karaoke atau Non Karaoke.
class SongFilterDropdown extends StatelessWidget {
  final SongFilter selectedFilter;
  final ValueChanged<SongFilter>? onChanged;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;

  const SongFilterDropdown({
    super.key,
    required this.selectedFilter,
    this.onChanged,
    this.backgroundColor = const Color(0xFF1E293B),
    this.borderColor = const Color(0x1FFFFFFF),
    this.foregroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SongFilter>(
          value: selectedFilter,
          isExpanded: true,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: foregroundColor,
            size: 20,
          ),
          dropdownColor: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          selectedItemBuilder: (context) {
            return SongFilter.values
                .map(
                  (filter) => Align(
                    alignment: Alignment.centerLeft,
                    child: _buildItem(filter, foregroundColor),
                  ),
                )
                .toList();
          },
          items: SongFilter.values
              .map(
                (filter) => DropdownMenuItem<SongFilter>(
                  value: filter,
                  child: _buildItem(filter, Colors.white),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next != null && next != selectedFilter) {
              onChanged?.call(next);
            }
          },
        ),
      ),
    );
  }

  Widget _buildItem(SongFilter filter, Color color) {
    return Row(
      children: [
        Icon(
          filter.isKaraoke ? Icons.mic_rounded : Icons.music_note_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            filter.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
