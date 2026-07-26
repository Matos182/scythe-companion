// SPDX-License-Identifier: MIT

// App-wide colour palette.
//
// Kept as top-level `const`s so any widget can build a `const` style
// without a BuildContext. The two names are easy to confuse:
// - bgColor    — the lighter teal page background.
// - bgColorBar — the darker slate used for AppBars and filled input
//                backgrounds (light text sits on top of it).
import 'package:flutter/material.dart';

const bgColor = Color.fromARGB(255, 114, 142, 145);

const bgColorBar = Color.fromARGB(225, 65, 77, 78);

const buttonTextColor = Color.fromARGB(255, 156, 160, 160);

const boxTextColor = Color.fromARGB(255, 156, 160, 160);

const unavailableColor = Color.fromARGB(255, 122, 120, 119);

const yourTurnColor = Color(0xff9c0303);

const yourTurnText = Colors.white;
