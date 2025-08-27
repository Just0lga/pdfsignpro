// ✅ Internet control
import 'dart:io';

Future<bool> hasInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com').timeout(
      Duration(seconds: 3),
    );

    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}
