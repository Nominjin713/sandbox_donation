import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color primaryColor = Color(0xFF287A55);

  final List<Map<String, String>> events = const [
    {
      'title': 'Мод тарих сайн дурын ажил',
      'organization': 'Ногоон ирээдүй ТББ',
      'date': '2026.10.25',
      'location': 'Улаанбаатар хот',
      'category': 'Байгаль орчин',
    },
    {
      'title': 'Хүүхдүүдэд тусалъя',
      'organization': 'Сайн үйлсийн төв',
      'date': '2026.10.28',
      'location': 'Сүхбаатар дүүрэг',
      'category': 'Нийгмийн сайн сайхан',
    },
    {
      'title': 'Хандивын арга хэмжээ',
      'organization': 'Ирээдүй клуб',
      'date': '2026.11.02',
      'location': 'Улаанбаатар хот',
      'category': 'Хүмүүнлэг',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.volunteer_activism, color: primaryColor, size: 30),
            SizedBox(width: 8),
            Text(
              'Volunteer Hub',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Сайн үйлсэд нэгдээрэй 💚',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Өөрийн цаг, сэтгэлээ зориулж бусдад туслаарай.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              hintText: 'Арга хэмжээ хайх...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Удахгүй болох арга хэмжээнүүд',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ...events.map(
            (event) => Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F3E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event['category']!,
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event['title']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('🏢 ${event['organization']}'),
                    const SizedBox(height: 7),
                    Text('📅 ${event['date']}'),
                    const SizedBox(height: 7),
                    Text('📍 ${event['location']}'),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Дэлгэрэнгүй үзэх'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
