/// Emblematic landmarks used to resolve a trustworthy national cover photo.
///
/// Keys match [kCountries] English names. Each entry lists Wikipedia page
/// titles (English) of famous places that visually identify the country.
class CountryLandmark {
  const CountryLandmark({
    required this.wikipediaTitle,
    required this.label,
    this.aliases = const <String>[],
  });

  /// English Wikipedia article title (spaces allowed).
  final String wikipediaTitle;

  /// Short human label shown in the UI badge.
  final String label;

  /// Extra title tokens accepted when matching Commons filenames.
  final List<String> aliases;

  List<String> get matchTokens {
    final Set<String> tokens = <String>{
      wikipediaTitle,
      label,
      ...aliases,
    };
    return tokens.toList(growable: false);
  }
}

/// Capitals used as a last-resort landmark when a country has few curated sites.
const Map<String, String> kCountryCapitals = <String, String>{
  'Afghanistan': 'Kabul',
  'Albania': 'Tirana',
  'Algeria': 'Algiers',
  'Andorra': 'Andorra la Vella',
  'Angola': 'Luanda',
  'Argentina': 'Buenos Aires',
  'Armenia': 'Yerevan',
  'Australia': 'Sydney',
  'Austria': 'Vienna',
  'Azerbaijan': 'Baku',
  'Bahamas': 'Nassau, Bahamas',
  'Bahrain': 'Manama',
  'Bangladesh': 'Dhaka',
  'Barbados': 'Bridgetown',
  'Belarus': 'Minsk',
  'Belgium': 'Brussels',
  'Belize': 'Belize City',
  'Benin': 'Cotonou',
  'Bhutan': 'Thimphu',
  'Bolivia': 'La Paz',
  'Bosnia and Herzegovina': 'Sarajevo',
  'Botswana': 'Gaborone',
  'Brazil': 'Rio de Janeiro',
  'Brunei': 'Bandar Seri Begawan',
  'Bulgaria': 'Sofia',
  'Burkina Faso': 'Ouagadougou',
  'Burundi': 'Bujumbura',
  'Cabo Verde': 'Praia, Cape Verde',
  'Cambodia': 'Angkor Wat',
  'Cameroon': 'Yaoundé',
  'Canada': 'Toronto',
  'Central African Republic': 'Bangui',
  'Chad': 'N\'Djamena',
  'Chile': 'Santiago',
  'China': 'Beijing',
  'Colombia': 'Bogotá',
  'Comoros': 'Moroni, Comoros',
  'Congo': 'Brazzaville',
  'Costa Rica': 'San José, Costa Rica',
  'Croatia': 'Dubrovnik',
  'Cuba': 'Havana',
  'Cyprus': 'Nicosia',
  'Czechia': 'Prague',
  'Democratic Republic of the Congo': 'Kinshasa',
  'Denmark': 'Copenhagen',
  'Djibouti': 'Djibouti City',
  'Dominica': 'Roseau',
  'Dominican Republic': 'Santo Domingo',
  'Ecuador': 'Quito',
  'Egypt': 'Cairo',
  'El Salvador': 'San Salvador',
  'Equatorial Guinea': 'Malabo',
  'Eritrea': 'Asmara',
  'Estonia': 'Tallinn',
  'Eswatini': 'Mbabane',
  'Ethiopia': 'Addis Ababa',
  'Fiji': 'Suva',
  'Finland': 'Helsinki',
  'France': 'Paris',
  'Gabon': 'Libreville',
  'Gambia': 'Banjul',
  'Georgia': 'Tbilisi',
  'Germany': 'Berlin',
  'Ghana': 'Accra',
  'Greece': 'Athens',
  'Grenada': 'St. George\'s, Grenada',
  'Guatemala': 'Antigua Guatemala',
  'Guinea': 'Conakry',
  'Guinea-Bissau': 'Bissau',
  'Guyana': 'Georgetown, Guyana',
  'Haiti': 'Port-au-Prince',
  'Honduras': 'Tegucigalpa',
  'Hungary': 'Budapest',
  'Iceland': 'Reykjavík',
  'India': 'New Delhi',
  'Indonesia': 'Jakarta',
  'Iran': 'Tehran',
  'Iraq': 'Baghdad',
  'Ireland': 'Dublin',
  'Israel': 'Jerusalem',
  'Italy': 'Rome',
  'Ivory Coast': 'Abidjan',
  'Jamaica': 'Kingston, Jamaica',
  'Japan': 'Tokyo',
  'Jordan': 'Amman',
  'Kazakhstan': 'Astana',
  'Kenya': 'Nairobi',
  'Kiribati': 'South Tarawa',
  'Kosovo': 'Pristina',
  'Kuwait': 'Kuwait City',
  'Kyrgyzstan': 'Bishkek',
  'Laos': 'Vientiane',
  'Latvia': 'Riga',
  'Lebanon': 'Beirut',
  'Lesotho': 'Maseru',
  'Liberia': 'Monrovia',
  'Libya': 'Tripoli, Libya',
  'Liechtenstein': 'Vaduz',
  'Lithuania': 'Vilnius',
  'Luxembourg': 'Luxembourg City',
  'Madagascar': 'Antananarivo',
  'Malawi': 'Lilongwe',
  'Malaysia': 'Kuala Lumpur',
  'Maldives': 'Malé',
  'Mali': 'Bamako',
  'Malta': 'Valletta',
  'Marshall Islands': 'Majuro',
  'Mauritania': 'Nouakchott',
  'Mauritius': 'Port Louis',
  'Mexico': 'Mexico City',
  'Micronesia': 'Palikir',
  'Moldova': 'Chișinău',
  'Monaco': 'Monaco',
  'Mongolia': 'Ulaanbaatar',
  'Montenegro': 'Podgorica',
  'Morocco': 'Marrakesh',
  'Mozambique': 'Maputo',
  'Myanmar': 'Yangon',
  'Namibia': 'Windhoek',
  'Nauru': 'Yaren District',
  'Nepal': 'Kathmandu',
  'Netherlands': 'Amsterdam',
  'New Zealand': 'Auckland',
  'Nicaragua': 'Managua',
  'Niger': 'Niamey',
  'Nigeria': 'Lagos',
  'North Korea': 'Pyongyang',
  'North Macedonia': 'Skopje',
  'Norway': 'Oslo',
  'Oman': 'Muscat',
  'Pakistan': 'Islamabad',
  'Palau': 'Koror',
  'Palestine': 'Jerusalem',
  'Panama': 'Panama City',
  'Papua New Guinea': 'Port Moresby',
  'Paraguay': 'Asunción',
  'Peru': 'Lima',
  'Philippines': 'Manila',
  'Poland': 'Warsaw',
  'Portugal': 'Lisbon',
  'Qatar': 'Doha',
  'Romania': 'Bucharest',
  'Russia': 'Moscow',
  'Rwanda': 'Kigali',
  'Saint Kitts and Nevis': 'Basseterre',
  'Saint Lucia': 'Castries',
  'Saint Vincent and the Grenadines': 'Kingstown',
  'Samoa': 'Apia',
  'San Marino': 'City of San Marino',
  'Sao Tome and Principe': 'São Tomé',
  'Saudi Arabia': 'Riyadh',
  'Senegal': 'Dakar',
  'Serbia': 'Belgrade',
  'Seychelles': 'Victoria, Seychelles',
  'Sierra Leone': 'Freetown',
  'Singapore': 'Singapore',
  'Slovakia': 'Bratislava',
  'Slovenia': 'Ljubljana',
  'Solomon Islands': 'Honiara',
  'Somalia': 'Mogadishu',
  'South Africa': 'Cape Town',
  'South Korea': 'Seoul',
  'South Sudan': 'Juba',
  'Spain': 'Madrid',
  'Sri Lanka': 'Colombo',
  'Sudan': 'Khartoum',
  'Suriname': 'Paramaribo',
  'Sweden': 'Stockholm',
  'Switzerland': 'Zurich',
  'Syria': 'Damascus',
  'Taiwan': 'Taipei',
  'Tajikistan': 'Dushanbe',
  'Tanzania': 'Dar es Salaam',
  'Thailand': 'Bangkok',
  'Timor-Leste': 'Dili',
  'Togo': 'Lomé',
  'Tonga': 'Nukuʻalofa',
  'Trinidad and Tobago': 'Port of Spain',
  'Tunisia': 'Tunis',
  'Turkey': 'Istanbul',
  'Turkmenistan': 'Ashgabat',
  'Tuvalu': 'Funafuti',
  'Uganda': 'Kampala',
  'Ukraine': 'Kyiv',
  'United Arab Emirates': 'Dubai',
  'United Kingdom': 'London',
  'United States': 'New York City',
  'Uruguay': 'Montevideo',
  'Uzbekistan': 'Tashkent',
  'Vanuatu': 'Port Vila',
  'Vatican City': 'Vatican City',
  'Venezuela': 'Caracas',
  'Vietnam': 'Hanoi',
  'Yemen': 'Sanaa',
  'Zambia': 'Lusaka',
  'Zimbabwe': 'Harare',
};

/// Curated emblematic landmarks (preferred before capitals).
const Map<String, List<CountryLandmark>> kCountryLandmarks =
    <String, List<CountryLandmark>>{
  'Algeria': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Casbah of Algiers',
      label: 'Casbah d\'Alger',
      aliases: <String>['Casbah of Algiers', 'Casbah d\'Alger'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Timgad',
      label: 'Timgad',
      aliases: <String>['Thamugadi'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Tassili n\'Ajjer',
      label: 'Tassili n\'Ajjer',
      aliases: <String>['Tassili n\'Ajjer', 'Tassili'],
    ),
  ],
  'Argentina': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Perito Moreno Glacier',
      label: 'Glacier Perito Moreno',
    ),
    CountryLandmark(
      wikipediaTitle: 'Iguazu Falls',
      label: 'Chutes d\'Iguazú',
      aliases: <String>['Iguazú', 'Iguaçu'],
    ),
  ],
  'Australia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Sydney Opera House',
      label: 'Opéra de Sydney',
    ),
    CountryLandmark(
      wikipediaTitle: 'Uluru',
      label: 'Uluru',
      aliases: <String>['Ayers Rock'],
    ),
  ],
  'Austria': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Schönbrunn Palace',
      label: 'Schönbrunn',
      aliases: <String>['Schoenbrunn'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Hallstatt',
      label: 'Hallstatt',
    ),
  ],
  'Belgium': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Grand-Place',
      label: 'Grand-Place de Bruxelles',
      aliases: <String>['Grand Place', 'Brussels'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Atomium',
      label: 'Atomium',
    ),
  ],
  'Brazil': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Christ the Redeemer',
      label: 'Christ Rédempteur',
      aliases: <String>[
        'Christ the Redeemer',
        'Cristo Redentor',
        'Corcovado',
      ],
    ),
    CountryLandmark(
      wikipediaTitle: 'Sugarloaf Mountain',
      label: 'Pain de Sucre',
      aliases: <String>['Sugarloaf Mountain', 'Sugarloaf', 'Pão de Açúcar'],
    ),
  ],
  'Cambodia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Angkor Wat',
      label: 'Angkor Wat',
    ),
  ],
  'Canada': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Niagara Falls',
      label: 'Chutes du Niagara',
    ),
    CountryLandmark(
      wikipediaTitle: 'CN Tower',
      label: 'Tour CN',
    ),
  ],
  'Chile': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Torres del Paine National Park',
      label: 'Torres del Paine',
    ),
    CountryLandmark(
      wikipediaTitle: 'Easter Island',
      label: 'Île de Pâques',
      aliases: <String>['Moai', 'Rapa Nui'],
    ),
  ],
  'China': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Great Wall of China',
      label: 'Grande Muraille',
      aliases: <String>['Great Wall'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Forbidden City',
      label: 'Cité interdite',
    ),
  ],
  'Colombia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Cartagena, Colombia',
      label: 'Carthagène',
      aliases: <String>['Cartagena'],
    ),
  ],
  'Croatia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Dubrovnik',
      label: 'Dubrovnik',
    ),
    CountryLandmark(
      wikipediaTitle: 'Plitvice Lakes National Park',
      label: 'Plitvice',
    ),
  ],
  'Cuba': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Old Havana',
      label: 'Vieille Havane',
      aliases: <String>['Havana', 'Habana'],
    ),
  ],
  'Czechia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Prague Castle',
      label: 'Château de Prague',
      aliases: <String>['Prague'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Charles Bridge',
      label: 'Pont Charles',
    ),
  ],
  'Denmark': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Nyhavn',
      label: 'Nyhavn',
    ),
  ],
  'Egypt': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Giza pyramid complex',
      label: 'Pyramides de Gizeh',
      aliases: <String>[
        'Pyramids of Giza',
        'Great Pyramid',
        'Giza pyramids',
        'Pyramid of Khufu',
      ],
    ),
    CountryLandmark(
      wikipediaTitle: 'Great Sphinx of Giza',
      label: 'Sphinx de Gizeh',
      aliases: <String>['Great Sphinx', 'Sphinx of Giza'],
    ),
  ],
  'Ethiopia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Lalibela',
      label: 'Lalibela',
    ),
  ],
  'Finland': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Helsinki Cathedral',
      label: 'Cathédrale d\'Helsinki',
    ),
  ],
  'France': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Eiffel Tower',
      label: 'Tour Eiffel',
      aliases: <String>['Tour Eiffel', 'Eiffel'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Mont-Saint-Michel',
      label: 'Mont-Saint-Michel',
      aliases: <String>['Mont Saint-Michel'],
    ),
  ],
  'Germany': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Brandenburg Gate',
      label: 'Porte de Brandebourg',
      aliases: <String>['Brandenburger Tor', 'Brandenburg'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Neuschwanstein Castle',
      label: 'Neuschwanstein',
      aliases: <String>['Neuschwanstein'],
    ),
  ],
  'Ghana': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Cape Coast Castle',
      label: 'Cape Coast Castle',
    ),
  ],
  'Greece': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Acropolis of Athens',
      label: 'Acropole d\'Athènes',
      aliases: <String>['Acropolis', 'Parthenon'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Santorini',
      label: 'Santorin',
      aliases: <String>['Thira'],
    ),
  ],
  'Hungary': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Hungarian Parliament Building',
      label: 'Parlement de Budapest',
      aliases: <String>['Parliament', 'Budapest'],
    ),
  ],
  'Iceland': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Hallgrímskirkja',
      label: 'Hallgrímskirkja',
      aliases: <String>['Hallgrimskirkja'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Blue Lagoon (geothermal spa)',
      label: 'Blue Lagoon',
    ),
  ],
  'India': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Taj Mahal',
      label: 'Taj Mahal',
    ),
    CountryLandmark(
      wikipediaTitle: 'Gateway of India',
      label: 'Gateway of India',
    ),
  ],
  'Indonesia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Borobudur',
      label: 'Borobudur',
    ),
    CountryLandmark(
      wikipediaTitle: 'Bali',
      label: 'Bali',
    ),
  ],
  'Iran': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Naqsh-e Jahan Square',
      label: 'Place Naghsh-e Jahan',
      aliases: <String>['Isfahan'],
    ),
  ],
  'Ireland': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Cliffs of Moher',
      label: 'Falaises de Moher',
    ),
  ],
  'Israel': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Western Wall',
      label: 'Mur des Lamentations',
      aliases: <String>['Kotel'],
    ),
  ],
  'Italy': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Colosseum',
      label: 'Colisée',
      aliases: <String>['Colosseo', 'Coliseum'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Venice',
      label: 'Venise',
      aliases: <String>['Venezia', 'Grand Canal'],
    ),
  ],
  'Japan': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Mount Fuji',
      label: 'Mont Fuji',
      aliases: <String>['Mount Fuji', 'Fujisan', 'Mt. Fuji'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Kiyomizu-dera',
      label: 'Kiyomizu-dera',
      aliases: <String>['Kiyomizu'],
    ),
  ],
  'Jordan': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Petra',
      label: 'Pétra',
      aliases: <String>['Al-Khazneh'],
    ),
  ],
  'Kenya': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Maasai Mara',
      label: 'Maasai Mara',
      aliases: <String>['Masai Mara'],
    ),
  ],
  'Malaysia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Petronas Towers',
      label: 'Tours Petronas',
    ),
  ],
  'Maldives': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Maldives',
      label: 'Maldives',
    ),
  ],
  'Mexico': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Chichen Itza',
      label: 'Chichén Itzá',
      aliases: <String>['Chichen'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Teotihuacan',
      label: 'Teotihuacan',
    ),
  ],
  'Morocco': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Jemaa el-Fnaa',
      label: 'Jemaa el-Fna',
      aliases: <String>['Jemaa el-Fnaa', 'Djemaa el Fna', 'Jamaa el Fna'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Chefchaouen',
      label: 'Chefchaouen',
      aliases: <String>['Chefchaouen', 'Chaouen'],
    ),
  ],
  'Nepal': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Mount Everest',
      label: 'Everest',
      aliases: <String>['Everest'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Boudhanath',
      label: 'Boudhanath',
    ),
  ],
  'Netherlands': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Keukenhof',
      label: 'Keukenhof',
    ),
    CountryLandmark(
      wikipediaTitle: 'Anne Frank House',
      label: 'Maison Anne Frank',
      aliases: <String>['Amsterdam'],
    ),
  ],
  'New Zealand': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Milford Sound',
      label: 'Milford Sound',
    ),
  ],
  'Nigeria': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'National Theatre, Lagos',
      label: 'Lagos',
      aliases: <String>['Lagos'],
    ),
  ],
  'Norway': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Geirangerfjord',
      label: 'Geirangerfjord',
      aliases: <String>['Geiranger'],
    ),
  ],
  'Peru': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Machu Picchu',
      label: 'Machu Picchu',
    ),
  ],
  'Poland': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Old Town, Warsaw',
      label: 'Vieille ville de Varsovie',
      aliases: <String>['Warsaw', 'Warszawa'],
    ),
  ],
  'Portugal': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Belém Tower',
      label: 'Tour de Belém',
      aliases: <String>['Belém Tower', 'Torre de Belém'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Pena Palace',
      label: 'Palais de Pena',
      aliases: <String>['Pena Palace', 'Palácio da Pena'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Jerónimos Monastery',
      label: 'Monastère des Jérónimos',
      aliases: <String>['Jerónimos', 'Jeronimos'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Dom Luís I Bridge',
      label: 'Pont Dom Luís',
      aliases: <String>['Dom Luís', 'Porto'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Praça do Comércio',
      label: 'Place du Commerce',
      aliases: <String>['Praça do Comércio', 'Terreiro do Paço'],
    ),
  ],
  'Russia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Saint Basil\'s Cathedral',
      label: 'Saint-Basile',
      aliases: <String>['St Basil', 'Red Square'],
    ),
  ],
  'Saudi Arabia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Masjid al-Haram',
      label: 'Masjid al-Haram',
      aliases: <String>['Mecca', 'Kaaba'],
    ),
  ],
  'Senegal': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'African Renaissance Monument',
      label: 'Monument de la Renaissance africaine',
      aliases: <String>[
        'African Renaissance Monument',
        'Monument de la Renaissance africaine',
        'Renaissance africaine',
      ],
    ),
    CountryLandmark(
      wikipediaTitle: 'Gorée',
      label: 'Île de Gorée',
      aliases: <String>['Goree', 'Gorée'],
    ),
  ],
  'Singapore': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Marina Bay Sands',
      label: 'Marina Bay Sands',
    ),
  ],
  'South Africa': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Table Mountain',
      label: 'Table Mountain',
      aliases: <String>['Cape Town'],
    ),
  ],
  'South Korea': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Gyeongbokgung',
      label: 'Gyeongbokgung',
      aliases: <String>['Seoul'],
    ),
  ],
  'Spain': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Sagrada Família',
      label: 'Sagrada Família',
      aliases: <String>['Sagrada Familia'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Plaza de España, Seville',
      label: 'Plaza de España',
      aliases: <String>['Seville', 'Sevilla'],
    ),
  ],
  'Sweden': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Gamla stan',
      label: 'Gamla stan',
      aliases: <String>['Stockholm'],
    ),
  ],
  'Switzerland': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Matterhorn',
      label: 'Cervin',
      aliases: <String>['Matterhorn', 'Cervin'],
    ),
  ],
  'Thailand': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Wat Arun',
      label: 'Wat Arun',
      aliases: <String>['Bangkok'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Grand Palace (Bangkok)',
      label: 'Grand Palais de Bangkok',
    ),
  ],
  'Tunisia': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Sidi Bou Said',
      label: 'Sidi Bou Saïd',
      aliases: <String>['Sidi Bou Said', 'Sidi Bou Saïd'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Amphitheatre of El Jem',
      label: 'Amphithéâtre d\'El Jem',
      aliases: <String>['El Jem', 'El Djem'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Tozeur',
      label: 'Désert de Tozeur',
      aliases: <String>['Tozeur', 'Sahara'],
    ),
  ],
  'Turkey': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Hagia Sophia',
      label: 'Sainte-Sophie',
      aliases: <String>['Aya Sofya', 'Hagia Sophia'],
    ),
    CountryLandmark(
      wikipediaTitle: 'Cappadocia',
      label: 'Cappadoce',
      aliases: <String>['Göreme', 'Goreme'],
    ),
  ],
  'Ukraine': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Saint Sophia Cathedral, Kyiv',
      label: 'Sainte-Sophie de Kyiv',
      aliases: <String>['Kyiv', 'Kiev'],
    ),
  ],
  'United Arab Emirates': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Burj Khalifa',
      label: 'Burj Khalifa',
    ),
  ],
  'United Kingdom': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Tower Bridge',
      label: 'Tower Bridge',
    ),
    CountryLandmark(
      wikipediaTitle: 'Big Ben',
      label: 'Big Ben',
      aliases: <String>['Elizabeth Tower', 'Parliament'],
    ),
  ],
  'United States': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Statue of Liberty',
      label: 'Statue de la Liberté',
    ),
    CountryLandmark(
      wikipediaTitle: 'Grand Canyon',
      label: 'Grand Canyon',
    ),
  ],
  'Vietnam': <CountryLandmark>[
    CountryLandmark(
      wikipediaTitle: 'Ha Long Bay',
      label: 'Baie d\'Ha Long',
      aliases: <String>['Halong'],
    ),
  ],
};

/// Resolves ordered landmarks for a country (curated first, then capital).
List<CountryLandmark> landmarksForCountry(String country) {
  final String key = country.trim();
  if (key.isEmpty) {
    return const <CountryLandmark>[];
  }
  final List<CountryLandmark> curated =
      List<CountryLandmark>.from(kCountryLandmarks[key] ?? const <CountryLandmark>[]);
  final String? capital = kCountryCapitals[key];
  if (capital != null &&
      !curated.any((CountryLandmark l) => l.wikipediaTitle == capital)) {
    curated.add(
      CountryLandmark(
        wikipediaTitle: capital,
        label: capital,
      ),
    );
  }
  // Final generic fallback: the country article itself.
  curated.add(
    CountryLandmark(
      wikipediaTitle: key,
      label: key,
    ),
  );
  return curated;
}
