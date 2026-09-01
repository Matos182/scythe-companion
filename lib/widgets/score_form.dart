// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../ui/theme.dart';

/// Shared score input form for the Scythe Coin Calculator.
///
/// Extracted (T1.3) from the duplicated field lists in `simple.dart` and
/// `player_add.dart`. Provides 7 [TextFormField]s with input validation:
/// popularity must be 0–18, all numeric fields must be ≥ 0 integers.
///
/// The parent owns the [controllers] (so it can read and dispose them).
/// [onSubmit] is called when the form is submitted via the keyboard's
/// "done" action or the parent's convert button.
class ScoreForm extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback? onSubmit;

  const ScoreForm({
    super.key,
    required this.controllers,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildField(
          controller: controllers[0],
          label: 'Player',
          icon: Icons.face_6,
          keyboardType: TextInputType.name,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a player name';
            }
            return null;
          },
        ),
        _buildField(
          controller: controllers[1],
          label: 'Popularity',
          icon: Icons.favorite,
          validator: (value) {
            final parsed = int.tryParse(value ?? '');
            if (parsed == null) return 'Enter a number';
            if (parsed < 0 || parsed > 18) return '0–18 only';
            return null;
          },
        ),
        _buildField(
          controller: controllers[2],
          label: 'Stars',
          icon: Icons.star,
          validator: _nonNegativeInt,
        ),
        _buildField(
          controller: controllers[3],
          label: 'Lands',
          icon: Icons.hexagon,
          validator: _nonNegativeInt,
        ),
        _buildField(
          controller: controllers[4],
          label: 'Resources',
          icon: Icons.my_library_add_rounded,
          validator: _nonNegativeInt,
        ),
        _buildField(
          controller: controllers[5],
          label: 'Building Coins',
          icon: Icons.home_filled,
          validator: _nonNegativeInt,
        ),
        _buildField(
          controller: controllers[6],
          label: 'Coins',
          icon: Icons.circle,
          validator: _nonNegativeInt,
          onSubmitted: onSubmit,
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.number,
    VoidCallback? onSubmitted,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 12, 7, 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: ScytheColors.brass),
        ),
        keyboardType: keyboardType,
        validator: validator,
        onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      ),
    );
  }

  static String? _nonNegativeInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be ≥ 0';
    return null;
  }
}
