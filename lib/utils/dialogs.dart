import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';

void confirmDelete({BuildContext context, VoidCallback callback}) {
  final localization = AppLocalization.of(context);

  showDialog<AlertDialog>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      semanticLabel: localization.areYouSure,
      title: Text(localization.areYouSure),
      actions: <Widget>[
        FlatButton(
            child: Text(localization.cancel.toUpperCase()),
            onPressed: () {
              Navigator.pop(context);
            }),
        FlatButton(
            child: Text(localization.ok.toUpperCase()),
            onPressed: () {
              Navigator.pop(context);
              callback();
            })
      ],
    ),
  );
}
