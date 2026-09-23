import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final DateFormat _longDate = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');

  static String date(DateTime dateTime) => _longDate.format(dateTime);

  static String dateTime(DateTime dateTime) => _dateTime.format(dateTime);

  static String compactNumber(num value) {
    return NumberFormat.compact().format(value);
  }

  static String currency(num value, {String symbol = 'INR '}) {
    return NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 0,
    ).format(value);
  }
}
