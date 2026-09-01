// SPDX-License-Identifier: MIT

import '../ui/theme.dart';

// Compatibility aliases for pre-T5.3 call sites. New UI code imports the
// centralized ScytheColors tokens directly.
@Deprecated('T5.3: use ScytheColors in lib/ui/theme.dart')
const bgColor = ScytheColors.coal;
const bgColorBar = ScytheColors.gunmetal;
const buttonTextColor = ScytheColors.parchment;
const boxTextColor = ScytheColors.parchment;
const unavailableColor = ScytheColors.disabled;
const yourTurnColor = ScytheColors.rust;
const yourTurnText = ScytheColors.parchment;
