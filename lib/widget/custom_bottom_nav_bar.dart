import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110, 
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black, // Fundal negru
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.home_filled, "Home", 0),
                  _buildNavItem(Icons.people_alt, "Friends", 1, hasBadge: true),
                  const SizedBox(width: 60),
                  _buildNavItem(Icons.map, "Mapa", 3), // Mapa în loc de Memories
                  _buildNavItem(Icons.person, "Profile", 4, hasBadge: true),
                ],
              ),
            ),
          ),
          Positioned(
            top: 5,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 65,
                height: 65,
                decoration: const BoxDecoration(
                  color: Colors.white, // Buton alb central
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.black, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {bool hasBadge = false}) {
    bool isSelected = currentIndex == index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onTap(index),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 26),
              if (hasBadge) // Bulina roșie
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 11)),
      ],
    );
  }
}