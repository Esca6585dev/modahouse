import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'strings.dart';

/// Flutter has no built-in Turkmen Material localizations, so the strings the
/// framework itself shows (tooltips, text selection menu, dialog labels, …)
/// are overridden here with Turkmen text from [S].
class TkMaterialLocalizations extends DefaultMaterialLocalizations {
  const TkMaterialLocalizations();

  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _Delegate();

  @override
  String get backButtonTooltip => S.back;
  @override
  String get closeButtonTooltip => S.close;
  @override
  String get closeButtonLabel => S.close;
  @override
  String get cancelButtonLabel => S.cancel;
  @override
  String get okButtonLabel => S.ok;
  @override
  String get continueButtonLabel => S.continueLabel;
  @override
  String get saveButtonLabel => S.save;
  @override
  String get deleteButtonTooltip => S.delete;
  @override
  String get clearButtonTooltip => S.searchClear;
  @override
  String get moreButtonTooltip => S.more;
  @override
  String get showMenuTooltip => S.showMenu;
  @override
  String get popupMenuLabel => S.menu;
  @override
  String get menuDismissLabel => S.close;
  @override
  String get dialogLabel => S.dialog;
  @override
  String get alertDialogLabel => S.dialog;
  @override
  String get bottomSheetLabel => S.bottomSheet;
  @override
  String get modalBarrierDismissLabel => S.close;
  @override
  String scrimOnTapHint(String modalRouteContentName) => S.close;
  @override
  String get searchFieldLabel => S.tabSearch;
  @override
  String get refreshIndicatorSemanticLabel => S.refresh;
  @override
  String get copyButtonLabel => S.copy;
  @override
  String get cutButtonLabel => S.cut;
  @override
  String get pasteButtonLabel => S.paste;
  @override
  String get selectAllButtonLabel => S.selectAll;
  @override
  String get shareButtonLabel => S.share;
  @override
  String get lookUpButtonLabel => S.lookUp;
  @override
  String get searchWebButtonLabel => S.searchWeb;
  @override
  String get openAppDrawerTooltip => S.menu;
  @override
  String get drawerLabel => S.menu;
}

class _Delegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(const TkMaterialLocalizations());

  @override
  bool shouldReload(_Delegate old) => false;
}
