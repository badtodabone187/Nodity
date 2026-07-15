import 'package:flutter/material.dart';

enum NotePrivacy { public, private, friends }
enum NoteVisibility { always, closeOnly, farOnly }

class Note {
  final String id;
  final String title;
  final String content;
  
  final double latitude;
  final double longitude;
  final double altitude;

  final IconData icon;
  final NotePrivacy privacy;
  final NoteVisibility visibility;
  final double distancePlaced;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.icon,
    this.privacy = NotePrivacy.public,
    this.visibility = NoteVisibility.always,
    required this.distancePlaced,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'iconCodePoint': icon.codePoint,
      'privacy': privacy.index,
      'visibility': visibility.index,
      'distancePlaced': distancePlaced,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      altitude: json['altitude'],
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
      privacy: NotePrivacy.values[json['privacy']],
      visibility: NoteVisibility.values[json['visibility']],
      distancePlaced: json['distancePlaced'],
    );
  }
}