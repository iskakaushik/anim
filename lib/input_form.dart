import 'package:flutter/material.dart';

typedef MapFunc = void Function(Map<String, int>);

class InputSettings extends StatefulWidget {
  final MapFunc successCallback;

  const InputSettings({Key key, this.successCallback}) : super(key: key);

  @override
  _InputSettingsState createState() => _InputSettingsState();
}

class _InputSettingsState extends State<InputSettings> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, int> values = Map();

  bool _isNumeric(String str) {
    if (str == null) {
      return false;
    }
    return int.tryParse(str) != null;
  }

  TextFormField validatedIntFormField(String label) {
    return TextFormField(
      validator: (String value) {
        if (value.isEmpty || !_isNumeric(value)) {
          return 'Please enter valid text.';
        }
        return null;
      },
      onSaved: (String value) {
        values[label] = int.parse(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          validatedIntFormField('label'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: RaisedButton(
              onPressed: () {
                if (_formKey.currentState.validate()) {
                  this.widget.successCallback?.call(values);
                }
              },
              child: Text('Simulate'),
            ),
          ),
        ],
      ),
    );
  }
}
