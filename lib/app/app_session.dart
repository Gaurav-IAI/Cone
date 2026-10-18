import 'package:flutter/foundation.dart';

import '../data/models.dart';

/// The signed-in person for this app run. Their role decides the colours and
/// which dashboard sections appear.
class AppSession extends ChangeNotifier {
  Person? _person;
  Uint8List? _selfie;

  Person? get person => _person;
  Role? get role => _person?.role;

  /// The person's selfie, loaded from local storage.
  Uint8List? get selfie => _selfie;

  void signIn(Person person, {Uint8List? selfie}) {
    _person = person;
    _selfie = selfie;
    notifyListeners();
  }

  void setSelfie(Uint8List? selfie) {
    _selfie = selfie;
    notifyListeners();
  }

  void signOut() {
    _person = null;
    _selfie = null;
    notifyListeners();
  }
}
