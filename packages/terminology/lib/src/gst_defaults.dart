/// Indian GST state codes and the services registration threshold table.
///
/// Registration is triggered only when a clinic makes a taxable supply and
/// its aggregate turnover (including exempt supplies) crosses the threshold
/// (docs/research/04-compliance-pricing-gtm.md, CGST s.22/s.23).
library;

/// One GST state / UT code (the first two digits of a GSTIN).
class GstStateCode {
  /// Creates a state code row.
  const GstStateCode(this.code, this.name, {this.retired = false});

  /// Two-digit code as printed in a GSTIN, e.g. `27`.
  final String code;

  /// State or territory name.
  final String name;

  /// True for codes no longer issued (merged or re-numbered territories).
  final bool retired;

  /// JSON map.
  Map<String, Object?> toJson() => {
    'code': code,
    'name': name,
    'retired': retired,
  };

  @override
  String toString() => '$code $name';
}

/// All GST state codes including retired ones, in code order.
const List<GstStateCode> gstStateCodes = [
  GstStateCode('01', 'Jammu and Kashmir'),
  GstStateCode('02', 'Himachal Pradesh'),
  GstStateCode('03', 'Punjab'),
  GstStateCode('04', 'Chandigarh'),
  GstStateCode('05', 'Uttarakhand'),
  GstStateCode('06', 'Haryana'),
  GstStateCode('07', 'Delhi'),
  GstStateCode('08', 'Rajasthan'),
  GstStateCode('09', 'Uttar Pradesh'),
  GstStateCode('10', 'Bihar'),
  GstStateCode('11', 'Sikkim'),
  GstStateCode('12', 'Arunachal Pradesh'),
  GstStateCode('13', 'Nagaland'),
  GstStateCode('14', 'Manipur'),
  GstStateCode('15', 'Mizoram'),
  GstStateCode('16', 'Tripura'),
  GstStateCode('17', 'Meghalaya'),
  GstStateCode('18', 'Assam'),
  GstStateCode('19', 'West Bengal'),
  GstStateCode('20', 'Jharkhand'),
  GstStateCode('21', 'Odisha'),
  GstStateCode('22', 'Chhattisgarh'),
  GstStateCode('23', 'Madhya Pradesh'),
  GstStateCode('24', 'Gujarat'),
  GstStateCode('25', 'Daman and Diu (merged into 26)', retired: true),
  GstStateCode('26', 'Dadra and Nagar Haveli and Daman and Diu'),
  GstStateCode('27', 'Maharashtra'),
  GstStateCode('28', 'Andhra Pradesh (before 2014; use 37)', retired: true),
  GstStateCode('29', 'Karnataka'),
  GstStateCode('30', 'Goa'),
  GstStateCode('31', 'Lakshadweep'),
  GstStateCode('32', 'Kerala'),
  GstStateCode('33', 'Tamil Nadu'),
  GstStateCode('34', 'Puducherry'),
  GstStateCode('35', 'Andaman and Nicobar Islands'),
  GstStateCode('36', 'Telangana'),
  GstStateCode('37', 'Andhra Pradesh'),
  GstStateCode('38', 'Ladakh'),
  GstStateCode('97', 'Other Territory'),
  GstStateCode('99', 'Centre Jurisdiction'),
];

/// Active (non-retired) state codes.
List<GstStateCode> get activeGstStateCodes =>
    gstStateCodes.where((s) => !s.retired).toList();

/// Looks up a state by two-digit code; null when unknown.
GstStateCode? gstStateByCode(String code) {
  final padded = code.trim().padLeft(2, '0');
  for (final s in gstStateCodes) {
    if (s.code == padded) return s;
  }
  return null;
}

/// State code embedded in a 15-character GSTIN, or null if malformed.
String? gstStateCodeFromGstin(String gstin) {
  final g = gstin.trim().toUpperCase();
  if (g.length != 15) return null;
  final code = g.substring(0, 2);
  return gstStateByCode(code)?.code;
}

/// Default aggregate-turnover threshold for services registration.
const int gstDefaultServicesThresholdRupees = 2000000;

/// Lower threshold still carried by four special-category states.
const int gstSpecialCategoryServicesThresholdRupees = 1000000;

/// Special-category states on the Rs 10 lakh services threshold: Manipur
/// (14), Mizoram (15), Nagaland (13) and Tripura (16).
///
/// Arunachal Pradesh (12) is deliberately left at Rs 20 lakh: the research
/// checkers disagreed (one said Rs 10 lakh, two said Rs 20 lakh), and the
/// state is not in the current Rs 10 lakh list for services, so it stays at
/// the default pending CA confirmation. Jammu and Kashmir, Ladakh, Assam,
/// Himachal, Sikkim, Meghalaya and Uttarakhand all opted up to Rs 20 lakh.
const Set<String> gstLowerThresholdStateCodes = {'13', '14', '15', '16'};

/// Services registration threshold in rupees for a clinic in [stateCode]:
/// Rs 20,00,000 by default, Rs 10,00,000 for [gstLowerThresholdStateCodes].
int gstRegistrationThresholdRupees(String stateCode) {
  final padded = stateCode.trim().padLeft(2, '0');
  return gstLowerThresholdStateCodes.contains(padded)
      ? gstSpecialCategoryServicesThresholdRupees
      : gstDefaultServicesThresholdRupees;
}
