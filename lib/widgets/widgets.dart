// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../utils/colors.dart';

final border = OutlineInputBorder(
  borderSide: const BorderSide(
    color: buttonTextColor,
    width: 2.0,
    style: BorderStyle.solid,
  ),
  borderRadius: BorderRadius.circular(10),
);

// Function to define input decoration for text fields
InputDecoration inputDecoration(String hintText, IconData prefixIcon) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: buttonTextColor),
    prefixIcon: Icon(prefixIcon, color: buttonTextColor),
    filled: true,
    fillColor: bgColorBar,
    focusedBorder: border,
    enabledBorder: border,
  );
}

// Function to build text fields
Widget buildTextField(TextEditingController controller, String hintText,
    IconData prefixIcon, TextInputType typeOfData) {
  return Container(
    padding: const EdgeInsets.fromLTRB(7, 12, 7, 12),
    child: TextField(
      controller: controller,
      style: const TextStyle(color: buttonTextColor),
      decoration: inputDecoration(hintText, prefixIcon),
      keyboardType: typeOfData,
    ),
  );
}

void showSnackBar(BuildContext context, String data) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(data),
    ),
  );
}
