import 'package:http/http.dart' as http;
import 'dart:convert';

class IpLocationService {
  // Detect country by IP
  static Future<Map<String, String>> detectCountryDetails() async {
    try {
      final response = await http.get(
        Uri.parse('https://ipapi.co/json/'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countryName = data['country_name'] as String?;
        final countryCode = data['country_code'] as String?;
        final dialCode = data['country_calling_code'] as String?;

        return {
          'name': countryName ?? 'Sri Lanka',
          'code': countryCode ?? 'LK',
          'dialCode': dialCode ?? '+94',
        };
      }
    } catch (e) {
      // Fallback
    }
    return {
      'name': 'Sri Lanka',
      'code': 'LK',
      'dialCode': '+94',
    };
  }

  // Get country details from phone number prefix
  static Map<String, String>? getCountryFromPrefix(String phoneNumber) {
    // Sort keys by length descending to match longest prefix first
    final sortedKeys = _countryDialCodes.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (var prefix in sortedKeys) {
      if (phoneNumber.startsWith(prefix)) {
        return {
          'name': _countryDialCodes[prefix]!,
          'dialCode': prefix,
        };
      }
    }
    return null;
  }

  static String getDialCode(String countryName) {
    for (var entry in _countryDialCodes.entries) {
      if (entry.value.toLowerCase() == countryName.toLowerCase()) {
        return entry.key;
      }
    }
    return '+94'; // Default
  }

  static const Map<String, String> _countryDialCodes = {
    '+93': 'Afghanistan',
    '+355': 'Albania',
    '+213': 'Algeria',
    '+1': 'United States', // Also Canada and others
    '+376': 'Andorra',
    '+244': 'Angola',
    '+1-264': 'Anguilla',
    '+1-268': 'Antigua and Barbuda',
    '+54': 'Argentina',
    '+374': 'Armenia',
    '+297': 'Aruba',
    '+61': 'Australia',
    '+43': 'Austria',
    '+994': 'Azerbaijan',
    '+1-242': 'Bahamas',
    '+973': 'Bahrain',
    '+880': 'Bangladesh',
    '+1-246': 'Barbados',
    '+375': 'Belarus',
    '+32': 'Belgium',
    '+501': 'Belize',
    '+229': 'Benin',
    '+1-441': 'Bermuda',
    '+975': 'Bhutan',
    '+591': 'Bolivia',
    '+387': 'Bosnia and Herzegovina',
    '+267': 'Botswana',
    '+55': 'Brazil',
    '+673': 'Brunei',
    '+359': 'Bulgaria',
    '+226': 'Burkina Faso',
    '+257': 'Burundi',
    '+855': 'Cambodia',
    '+237': 'Cameroon',
    '+238': 'Cape Verde',
    '+1-345': 'Cayman Islands',
    '+236': 'Central African Republic',
    '+235': 'Chad',
    '+56': 'Chile',
    '+86': 'China',
    '+57': 'Colombia',
    '+269': 'Comoros',
    '+242': 'Congo',
    '+243': 'Congo, Democratic Republic of the',
    '+682': 'Cook Islands',
    '+506': 'Costa Rica',
    '+385': 'Croatia',
    '+53': 'Cuba',
    '+357': 'Cyprus',
    '+420': 'Czech Republic',
    '+45': 'Denmark',
    '+253': 'Djibouti',
    '+1-767': 'Dominica',
    '+1-809': 'Dominican Republic',
    '+593': 'Ecuador',
    '+20': 'Egypt',
    '+503': 'El Salvador',
    '+240': 'Equatorial Guinea',
    '+291': 'Eritrea',
    '+372': 'Estonia',
    '+251': 'Ethiopia',
    '+500': 'Falkland Islands',
    '+298': 'Faroe Islands',
    '+679': 'Fiji',
    '+358': 'Finland',
    '+33': 'France',
    '+594': 'French Guiana',
    '+689': 'French Polynesia',
    '+241': 'Gabon',
    '+220': 'Gambia',
    '+995': 'Georgia',
    '+49': 'Germany',
    '+233': 'Ghana',
    '+350': 'Gibraltar',
    '+30': 'Greece',
    '+299': 'Greenland',
    '+1-473': 'Grenada',
    '+590': 'Guadeloupe',
    '+1-671': 'Guam',
    '+502': 'Guatemala',
    '+224': 'Guinea',
    '+245': 'Guinea-Bissau',
    '+592': 'Guyana',
    '+509': 'Haiti',
    '+504': 'Honduras',
    '+852': 'Hong Kong',
    '+36': 'Hungary',
    '+354': 'Iceland',
    '+91': 'India',
    '+62': 'Indonesia',
    '+98': 'Iran',
    '+964': 'Iraq',
    '+353': 'Ireland',
    '+972': 'Israel',
    '+39': 'Italy',
    '+1-876': 'Jamaica',
    '+81': 'Japan',
    '+962': 'Jordan',
    '+7': 'Russia',
    '+254': 'Kenya',
    '+686': 'Kiribati',
    '+965': 'Kuwait',
    '+996': 'Kyrgyzstan',
    '+856': 'Laos',
    '+371': 'Latvia',
    '+961': 'Lebanon',
    '+266': 'Lesotho',
    '+231': 'Liberia',
    '+218': 'Libya',
    '+423': 'Liechtenstein',
    '+370': 'Lithuania',
    '+352': 'Luxembourg',
    '+853': 'Macau',
    '+389': 'Macedonia',
    '+261': 'Madagascar',
    '+265': 'Malawi',
    '+60': 'Malaysia',
    '+960': 'Maldives',
    '+223': 'Mali',
    '+356': 'Malta',
    '+692': 'Marshall Islands',
    '+596': 'Martinique',
    '+222': 'Mauritania',
    '+230': 'Mauritius',
    '+262-1': 'Mayotte', // Use suffix to distinguish in constant map
    '+52': 'Mexico',
    '+691': 'Micronesia',
    '+373': 'Moldova',
    '+377': 'Monaco',
    '+976': 'Mongolia',
    '+382': 'Montenegro',
    '+1-664': 'Montserrat',
    '+212': 'Morocco',
    '+258': 'Mozambique',
    '+95': 'Myanmar',
    '+264': 'Namibia',
    '+674': 'Nauru',
    '+977': 'Nepal',
    '+31': 'Netherlands',
    '+687': 'New Caledonia',
    '+64': 'New Zealand',
    '+505': 'Nicaragua',
    '+227': 'Niger',
    '+234': 'Nigeria',
    '+683': 'Niue',
    '+672': 'Norfolk Island',
    '+850': 'North Korea',
    '+1-670': 'Northern Mariana Islands',
    '+47': 'Norway',
    '+968': 'Oman',
    '+92': 'Pakistan',
    '+680': 'Palau',
    '+970': 'Palestine',
    '+507': 'Panama',
    '+675': 'Papua New Guinea',
    '+595': 'Paraguay',
    '+51': 'Peru',
    '+63': 'Philippines',
    '+48': 'Poland',
    '+351': 'Portugal',
    '+1-787': 'Puerto Rico',
    '+974': 'Qatar',
    '+262': 'Reunion',
    '+40': 'Romania',
    '+250': 'Rwanda',
    '+1-869': 'Saint Kitts and Nevis',
    '+1-758': 'Saint Lucia',
    '+1-784': 'Saint Vincent and the Grenadines',
    '+685': 'Samoa',
    '+378': 'San Marino',
    '+239': 'Sao Tome and Principe',
    '+966': 'Saudi Arabia',
    '+221': 'Senegal',
    '+381': 'Serbia',
    '+248': 'Seychelles',
    '+232': 'Sierra Leone',
    '+65': 'Singapore',
    '+421': 'Slovakia',
    '+386': 'Slovenia',
    '+677': 'Solomon Islands',
    '+252': 'Somalia',
    '+27': 'South Africa',
    '+82': 'South Korea',
    '+34': 'Spain',
    '+94': 'Sri Lanka',
    '+249': 'Sudan',
    '+597': 'Suriname',
    '+268': 'Swaziland',
    '+46': 'Sweden',
    '+41': 'Switzerland',
    '+963': 'Syria',
    '+886': 'Taiwan',
    '+992': 'Tajikistan',
    '+255': 'Tanzania',
    '+66': 'Thailand',
    '+670': 'Timor-Leste',
    '+228': 'Togo',
    '+690': 'Tokelau',
    '+676': 'Tonga',
    '+1-868': 'Trinidad and Tobago',
    '+216': 'Tunisia',
    '+90': 'Turkey',
    '+993': 'Turkmenistan',
    '+1-649': 'Turks and Caicos Islands',
    '+688': 'Tuvalu',
    '+256': 'Uganda',
    '+380': 'Ukraine',
    '+971': 'UAE',
    '+44': 'United Kingdom',
    '+598': 'Uruguay',
    '+998': 'Uzbekistan',
    '+678': 'Vanuatu',
    '+58': 'Venezuela',
    '+84': 'Vietnam',
    '+1-284': 'Virgin Islands, British',
    '+1-340': 'Virgin Islands, U.S.',
    '+681': 'Wallis and Futuna',
    '+967': 'Yemen',
    '+260': 'Zambia',
    '+263': 'Zimbabwe',
  };

  static List<String> getAllCountries() {
    return _countryDialCodes.values.toSet().toList()..sort();
  }
}