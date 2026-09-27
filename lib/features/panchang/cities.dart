/// Embedded city database for Panchang calculations.
/// All coordinates are approximate (city-centre) and are used only for
/// astronomical rise/set/timing computations; every Indian city uses IST
/// (+330 min). A few non-Indian cities are included for completeness.
library;

class City {
  const City(this.name, this.state, this.lat, this.lon,
      [this.tzOffsetMin = 330]);
  final String name;
  final String state;
  final double lat; // +N
  final double lon; // +E
  final int tzOffsetMin;

  String get label => name;
}

const availableCities = <City>[
  City('Varanasi', 'Uttar Pradesh', 25.3176, 82.9739),
  City('New Delhi', 'Delhi', 28.6139, 77.2090),
  City('Mumbai', 'Maharashtra', 19.0760, 72.8777),
  City('Kolkata', 'West Bengal', 22.5726, 88.3639),
  City('Chennai', 'Tamil Nadu', 13.0827, 80.2707),
  City('Bengaluru', 'Karnataka', 12.9716, 77.5946),
  City('Hyderabad', 'Telangana', 17.3850, 78.4867),
  City('Ahmedabad', 'Gujarat', 23.0225, 72.5714),
  City('Pune', 'Maharashtra', 18.5204, 73.8567),
  City('Jaipur', 'Rajasthan', 26.9124, 75.7873),
  City('Lucknow', 'Uttar Pradesh', 26.8467, 80.9462),
  City('Kanpur', 'Uttar Pradesh', 26.4499, 80.3319),
  City('Nagpur', 'Maharashtra', 21.1458, 79.0882),
  City('Indore', 'Madhya Pradesh', 22.7196, 75.8577),
  City('Bhopal', 'Madhya Pradesh', 23.2599, 77.4126),
  City('Patna', 'Bihar', 25.5941, 85.1376),
  City('Prayagraj', 'Uttar Pradesh', 25.4358, 81.8463),
  City('Ayodhya', 'Uttar Pradesh', 26.7922, 82.1998),
  City('Mathura', 'Uttar Pradesh', 27.4924, 77.6737),
  City('Vrindavan', 'Uttar Pradesh', 27.5798, 77.7001),
  City('Gorakhpur', 'Uttar Pradesh', 26.7606, 83.3732),
  City('Agra', 'Uttar Pradesh', 27.1767, 78.0081),
  City('Surat', 'Gujarat', 21.1702, 72.8311),
  City('Vadodara', 'Gujarat', 22.3072, 73.1812),
  City('Nashik', 'Maharashtra', 19.9975, 73.7898),
  City('Aurangabad', 'Maharashtra', 19.8762, 75.3433),
  City('Amritsar', 'Punjab', 31.6340, 74.8723),
  City('Ludhiana', 'Punjab', 30.9010, 75.8573),
  City('Chandigarh', 'Chandigarh', 30.7333, 76.7794),
  City('Dehradun', 'Uttarakhand', 30.3165, 78.0322),
  City('Haridwar', 'Uttarakhand', 29.9457, 78.1642),
  City('Rishikesh', 'Uttarakhand', 30.0869, 78.2676),
  City('Shimla', 'Himachal Pradesh', 31.1048, 77.1734),
  City('Srinagar', 'Jammu & Kashmir', 34.0837, 74.7973),
  City('Jammu', 'Jammu & Kashmir', 32.7266, 74.8570),
  City('Raipur', 'Chhattisgarh', 21.2514, 81.6296),
  City('Bhubaneswar', 'Odisha', 20.2961, 85.8245),
  City('Cuttack', 'Odisha', 20.4625, 85.8828),
  City('Guwahati', 'Assam', 26.1445, 91.7362),
  City('Shillong', 'Meghalaya', 25.5788, 91.8933),
  City('Imphal', 'Manipur', 24.8170, 93.9368),
  City('Agartala', 'Tripura', 23.8315, 91.2868),
  City('Aizawl', 'Mizoram', 23.7271, 92.7176),
  City('Kohima', 'Nagaland', 25.6751, 94.1086),
  City('Itanagar', 'Arunachal Pradesh', 27.0844, 93.6053),
  City('Gangtok', 'Sikkim', 27.3389, 88.6065),
  City('Ranchi', 'Jharkhand', 23.3441, 85.3096),
  City('Jamshedpur', 'Jharkhand', 22.8046, 86.2029),
  City('Kochi', 'Kerala', 9.9312, 76.2673),
  City('Thiruvananthapuram', 'Kerala', 8.5241, 76.9366),
  City('Madurai', 'Tamil Nadu', 9.9252, 78.1198),
  City('Coimbatore', 'Tamil Nadu', 11.0168, 76.9558),
  City('Tiruchirappalli', 'Tamil Nadu', 10.7905, 78.7047),
  City('Vijayawada', 'Andhra Pradesh', 16.5062, 80.6480),
  City('Visakhapatnam', 'Andhra Pradesh', 17.6868, 83.2185),
  City('Tirupati', 'Andhra Pradesh', 13.6288, 79.4192),
  City('Kurnool', 'Andhra Pradesh', 15.8281, 78.0373),
  City('Mysuru', 'Karnataka', 12.2958, 76.6394),
  City('Mangaluru', 'Karnataka', 12.9141, 74.8560),
  City('Udupi', 'Karnataka', 13.3409, 74.7421),
  City('Ujjain', 'Madhya Pradesh', 23.1765, 75.7885),
  City('Gwalior', 'Madhya Pradesh', 26.2183, 78.1828),
  City('Jabalpur', 'Madhya Pradesh', 23.1815, 79.9864),
  City('Deoghar', 'Jharkhand', 24.4803, 86.6999),
  City('Udaipur', 'Rajasthan', 24.5854, 73.7125),
  City('Jodhpur', 'Rajasthan', 26.2389, 73.0243),
  City('Gandhinagar', 'Gujarat', 23.2156, 72.6369),
  City('Rajkot', 'Gujarat', 22.3039, 70.8022),
  City('Hubli', 'Karnataka', 15.3647, 75.1240),
  City('Kathmandu', 'Nepal', 27.7172, 85.3240, 345),
];

City? cityByName(String name) {
  for (final c in availableCities) {
    if (c.name == name) return c;
  }
  return null;
}

City defaultCity() => availableCities.first; // Varanasi

/// Fall back to Varanasi when the stored city name is unknown.
City cityOrFallback(String name) => cityByName(name) ?? defaultCity();
