// To parse this JSON data, do
//
//     final factionCrimesModel = factionCrimesModelFromJson(jsonString);

import 'dart:convert';

FactionCrimesModel factionCrimesModelFromJson(String str) => FactionCrimesModel.fromJson(json.decode(str));

String factionCrimesModelToJson(FactionCrimesModel data) => json.encode(data.toJson());

class FactionCrimesModel {
  FactionCrimesModel({
    this.crimes,
  });

  Map<String, Crime> crimes;

  factory FactionCrimesModel.fromJson(Map<String, dynamic> json) => FactionCrimesModel(
    crimes: json["crimes"] == null ? null : Map.from(json["crimes"]).map((k, v) => MapEntry<String, Crime>(k, Crime.fromJson(v))),
  );

  Map<String, dynamic> toJson() => {
    "crimes": crimes == null ? null : Map.from(crimes).map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
  };
}

class Crime {
  Crime({
    this.crimeId,
    this.crimeName,
    this.participants,
    this.timeStarted,
    this.timeReady,
    this.timeLeft,
    this.timeCompleted,
    this.initiated,
    this.initiatedBy,
    this.plannedBy,
    this.success,
    this.moneyGain,
    this.respectGain,
  });

  int crimeId;
  String crimeName;
  List<Map<String, Participant>> participants;
  int timeStarted;
  int timeReady;
  int timeLeft;
  int timeCompleted;
  int initiated;
  int initiatedBy;
  int plannedBy;
  int success;
  int moneyGain;
  int respectGain;

  factory Crime.fromJson(Map<String, dynamic> json) => Crime(
    crimeId: json["crime_id"] == null ? null : json["crime_id"],
    crimeName: json["crime_name"] == null ? null : json["crime_name"],
    participants: json["participants"] == null ? null : List<Map<String, Participant>>.from(json["participants"].map((x) => Map.from(x).map((k, v) => MapEntry<String, Participant>(k, v == null ? null : Participant.fromJson(v))))),
    timeStarted: json["time_started"] == null ? null : json["time_started"],
    timeReady: json["time_ready"] == null ? null : json["time_ready"],
    timeLeft: json["time_left"] == null ? null : json["time_left"],
    timeCompleted: json["time_completed"] == null ? null : json["time_completed"],
    initiated: json["initiated"] == null ? null : json["initiated"],
    initiatedBy: json["initiated_by"] == null ? null : json["initiated_by"],
    plannedBy: json["planned_by"] == null ? null : json["planned_by"],
    success: json["success"] == null ? null : json["success"],
    moneyGain: json["money_gain"] == null ? null : json["money_gain"],
    respectGain: json["respect_gain"] == null ? null : json["respect_gain"],
  );

  Map<String, dynamic> toJson() => {
    "crime_id": crimeId == null ? null : crimeId,
    "crime_name": crimeName == null ? null : crimeName,
    "participants": participants == null ? null : List<dynamic>.from(participants.map((x) => Map.from(x).map((k, v) => MapEntry<String, dynamic>(k, v == null ? null : v.toJson())))),
    "time_started": timeStarted == null ? null : timeStarted,
    "time_ready": timeReady == null ? null : timeReady,
    "time_left": timeLeft == null ? null : timeLeft,
    "time_completed": timeCompleted == null ? null : timeCompleted,
    "initiated": initiated == null ? null : initiated,
    "initiated_by": initiatedBy == null ? null : initiatedBy,
    "planned_by": plannedBy == null ? null : plannedBy,
    "success": success == null ? null : success,
    "money_gain": moneyGain == null ? null : moneyGain,
    "respect_gain": respectGain == null ? null : respectGain,
  };
}

class Participant {
  Participant({
    this.description,
    this.details,
    this.state,
    this.color,
    this.until,
  });

  String description;
  String details;
  String state;
  String color;
  int until;

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
    description: json["description"] == null ? null : json["description"],
    details: json["details"] == null ? null : json["details"],
    state: json["state"] == null ? null : json["state"],
    color: json["color"] == null ? null : json["color"],
    until: json["until"] == null ? null : json["until"],
  );

  Map<String, dynamic> toJson() => {
    "description": description == null ? null : description,
    "details": details == null ? null : details,
    "state": state == null ? null : state,
    "color": color == null ? null : color,
    "until": until == null ? null : until,
  };
}
