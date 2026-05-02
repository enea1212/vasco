import 'package:flutter/material.dart';

class TinderCard extends StatelessWidget {
  final Map<String, dynamic> profile;

  const TinderCard({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        image: DecorationImage(
          // Folosim o imagine de placeholder dacă profilul nu are poză
          image: NetworkImage(profile['photoUrl'] ?? 'https://via.placeholder.com/400x600.png?text=Fara+Poza'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        // Adăugăm un gradient negru în partea de jos pentru ca textul să fie lizibil
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Colors.transparent, Colors.black87],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.6, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    profile['displayName'] ?? 'Anonim',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Dacă trimiți vârsta din funcția Cloud, o poți afișa aici
                ],
              ),
              const SizedBox(height: 5),
              if (profile['distanceInKm'] != null)
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      'La ${profile['distanceInKm']} km distanță',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              if (profile['bio'] != null)
                Text(
                  profile['bio'],
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}