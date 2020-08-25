// To parse this JSON data, do
//
//     final companyModel = companyModelFromJson(jsonString);

import 'dart:convert';

CompanyModel companyModelFromJson(String str) => CompanyModel.fromJson(json.decode(str));

String companyModelToJson(CompanyModel data) => json.encode(data.toJson());

class CompanyModel {
  CompanyModel({
    this.timestamp,
    this.companyDetailed,
    this.company,
    this.companyEmployees,
    this.news,
    this.companyStock,
  });

  int timestamp;
  CompanyDetailed companyDetailed;
  Company company;
  Map<String, CompanyEmployee> companyEmployees;
  Map<String, News> news;
  CompanyStock companyStock;

  factory CompanyModel.fromJson(Map<String, dynamic> json) => CompanyModel(
    timestamp: json["timestamp"] == null ? null : json["timestamp"],
    companyDetailed: json["company_detailed"] == null ? null : CompanyDetailed.fromJson(json["company_detailed"]),
    company: json["company"] == null ? null : Company.fromJson(json["company"]),
    companyEmployees: json["company_employees"] == null ? null : Map.from(json["company_employees"]).map((k, v) => MapEntry<String, CompanyEmployee>(k, CompanyEmployee.fromJson(v))),
    news: json["news"] == null ? null : Map.from(json["news"]).map((k, v) => MapEntry<String, News>(k, News.fromJson(v))),
    companyStock: json["company_stock"] == null ? null : CompanyStock.fromJson(json["company_stock"]),
  );

  Map<String, dynamic> toJson() => {
    "timestamp": timestamp == null ? null : timestamp,
    "company_detailed": companyDetailed == null ? null : companyDetailed.toJson(),
    "company": company == null ? null : company.toJson(),
    "company_employees": companyEmployees == null ? null : Map.from(companyEmployees).map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
    "news": news == null ? null : Map.from(news).map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
    "company_stock": companyStock == null ? null : companyStock.toJson(),
  };
}

class Company {
  Company({
    this.id,
    this.companyType,
    this.rating,
    this.name,
    this.director,
    this.employeesHired,
    this.employeesCapacity,
    this.dailyIncome,
    this.dailyCustomers,
    this.weeklyIncome,
    this.weeklyCustomers,
    this.daysOld,
    this.employees,
  });

  int id;
  int companyType;
  int rating;
  String name;
  int director;
  int employeesHired;
  int employeesCapacity;
  int dailyIncome;
  int dailyCustomers;
  int weeklyIncome;
  int weeklyCustomers;
  int daysOld;
  Map<String, Employee> employees;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json["ID"] == null ? null : json["ID"],
    companyType: json["company_type"] == null ? null : json["company_type"],
    rating: json["rating"] == null ? null : json["rating"],
    name: json["name"] == null ? null : json["name"],
    director: json["director"] == null ? null : json["director"],
    employeesHired: json["employees_hired"] == null ? null : json["employees_hired"],
    employeesCapacity: json["employees_capacity"] == null ? null : json["employees_capacity"],
    dailyIncome: json["daily_income"] == null ? null : json["daily_income"],
    dailyCustomers: json["daily_customers"] == null ? null : json["daily_customers"],
    weeklyIncome: json["weekly_income"] == null ? null : json["weekly_income"],
    weeklyCustomers: json["weekly_customers"] == null ? null : json["weekly_customers"],
    daysOld: json["days_old"] == null ? null : json["days_old"],
    employees: json["employees"] == null ? null : Map.from(json["employees"]).map((k, v) => MapEntry<String, Employee>(k, Employee.fromJson(v))),
  );

  Map<String, dynamic> toJson() => {
    "ID": id == null ? null : id,
    "company_type": companyType == null ? null : companyType,
    "rating": rating == null ? null : rating,
    "name": name == null ? null : name,
    "director": director == null ? null : director,
    "employees_hired": employeesHired == null ? null : employeesHired,
    "employees_capacity": employeesCapacity == null ? null : employeesCapacity,
    "daily_income": dailyIncome == null ? null : dailyIncome,
    "daily_customers": dailyCustomers == null ? null : dailyCustomers,
    "weekly_income": weeklyIncome == null ? null : weeklyIncome,
    "weekly_customers": weeklyCustomers == null ? null : weeklyCustomers,
    "days_old": daysOld == null ? null : daysOld,
    "employees": employees == null ? null : Map.from(employees).map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
  };
}

class Employee {
  Employee({
    this.name,
    this.position,
    this.daysInCompany,
    this.lastAction,
    this.status,
  });

  String name;
  String position;
  int daysInCompany;
  LastAction lastAction;
  StatusClass status;

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    name: json["name"] == null ? null : json["name"],
    position: json["position"] == null ? null : json["position"],
    daysInCompany: json["days_in_company"] == null ? null : json["days_in_company"],
    lastAction: json["last_action"] == null ? null : LastAction.fromJson(json["last_action"]),
    status: json["status"] == null ? null : StatusClass.fromJson(json["status"]),
  );

  Map<String, dynamic> toJson() => {
    "name": name == null ? null : name,
    "position": position == null ? null : position,
    "days_in_company": daysInCompany == null ? null : daysInCompany,
    "last_action": lastAction == null ? null : lastAction.toJson(),
    "status": status == null ? null : status.toJson(),
  };
}

class LastAction {
  LastAction({
    this.status,
    this.timestamp,
    this.relative,
  });

  String status;
  int timestamp;
  String relative;

  factory LastAction.fromJson(Map<String, dynamic> json) => LastAction(
    status: json["status"] == null ? null : json["status"],
    timestamp: json["timestamp"] == null ? null : json["timestamp"],
    relative: json["relative"] == null ? null : json["relative"],
  );

  Map<String, dynamic> toJson() => {
    "status": status == null ? null : status,
    "timestamp": timestamp == null ? null : timestamp,
    "relative": relative == null ? null : relative,
  };
}

class StatusClass {
  StatusClass({
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

  factory StatusClass.fromJson(Map<String, dynamic> json) => StatusClass(
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

class CompanyDetailed {
  CompanyDetailed({
    this.id,
    this.companyBank,
    this.popularity,
    this.efficiency,
    this.environment,
    this.trainsAvailable,
    this.advertisingBudget,
    this.upgrades,
  });

  int id;
  int companyBank;
  int popularity;
  int efficiency;
  int environment;
  int trainsAvailable;
  int advertisingBudget;
  Upgrades upgrades;

  factory CompanyDetailed.fromJson(Map<String, dynamic> json) => CompanyDetailed(
    id: json["ID"] == null ? null : json["ID"],
    companyBank: json["company_bank"] == null ? null : json["company_bank"],
    popularity: json["popularity"] == null ? null : json["popularity"],
    efficiency: json["efficiency"] == null ? null : json["efficiency"],
    environment: json["environment"] == null ? null : json["environment"],
    trainsAvailable: json["trains_available"] == null ? null : json["trains_available"],
    advertisingBudget: json["advertising_budget"] == null ? null : json["advertising_budget"],
    upgrades: json["upgrades"] == null ? null : Upgrades.fromJson(json["upgrades"]),
  );

  Map<String, dynamic> toJson() => {
    "ID": id == null ? null : id,
    "company_bank": companyBank == null ? null : companyBank,
    "popularity": popularity == null ? null : popularity,
    "efficiency": efficiency == null ? null : efficiency,
    "environment": environment == null ? null : environment,
    "trains_available": trainsAvailable == null ? null : trainsAvailable,
    "advertising_budget": advertisingBudget == null ? null : advertisingBudget,
    "upgrades": upgrades == null ? null : upgrades.toJson(),
  };
}

class Upgrades {
  Upgrades({
    this.companySize,
    this.staffroomSize,
    this.storageSize,
    this.storageSpace,
  });

  int companySize;
  String staffroomSize;
  String storageSize;
  int storageSpace;

  factory Upgrades.fromJson(Map<String, dynamic> json) => Upgrades(
    companySize: json["company_size"] == null ? null : json["company_size"],
    staffroomSize: json["staffroom_size"] == null ? null : json["staffroom_size"],
    storageSize: json["storage_size"] == null ? null : json["storage_size"],
    storageSpace: json["storage_space"] == null ? null : json["storage_space"],
  );

  Map<String, dynamic> toJson() => {
    "company_size": companySize == null ? null : companySize,
    "staffroom_size": staffroomSize == null ? null : staffroomSize,
    "storage_size": storageSize == null ? null : storageSize,
    "storage_space": storageSpace == null ? null : storageSpace,
  };
}

class CompanyEmployee {
  CompanyEmployee({
    this.name,
    this.position,
    this.daysInCompany,
    this.wage,
    this.effectiveness,
    this.manualLabor,
    this.intelligence,
    this.endurance,
    this.lastAction,
    this.status,
  });

  String name;
  String position;
  int daysInCompany;
  int wage;
  int effectiveness;
  int manualLabor;
  int intelligence;
  int endurance;
  LastAction lastAction;
  StatusClass status;

  factory CompanyEmployee.fromJson(Map<String, dynamic> json) => CompanyEmployee(
    name: json["name"] == null ? null : json["name"],
    position: json["position"] == null ? null : json["position"],
    daysInCompany: json["days_in_company"] == null ? null : json["days_in_company"],
    wage: json["wage"] == null ? null : json["wage"],
    effectiveness: json["effectiveness"] == null ? null : json["effectiveness"],
    manualLabor: json["manual_labor"] == null ? null : json["manual_labor"],
    intelligence: json["intelligence"] == null ? null : json["intelligence"],
    endurance: json["endurance"] == null ? null : json["endurance"],
    lastAction: json["last_action"] == null ? null : LastAction.fromJson(json["last_action"]),
    status: json["status"] == null ? null : StatusClass.fromJson(json["status"]),
  );

  Map<String, dynamic> toJson() => {
    "name": name == null ? null : name,
    "position": position == null ? null : position,
    "days_in_company": daysInCompany == null ? null : daysInCompany,
    "wage": wage == null ? null : wage,
    "effectiveness": effectiveness == null ? null : effectiveness,
    "manual_labor": manualLabor == null ? null : manualLabor,
    "intelligence": intelligence == null ? null : intelligence,
    "endurance": endurance == null ? null : endurance,
    "last_action": lastAction == null ? null : lastAction.toJson(),
    "status": status == null ? null : status.toJson(),
  };
}

class CompanyStock {
  CompanyStock({
    this.admission,
    this.lapDance,
    this.tips,
    this.special,
  });

  Admission admission;
  Admission lapDance;
  Admission tips;
  Admission special;

  factory CompanyStock.fromJson(Map<String, dynamic> json) => CompanyStock(
    admission: json["Admission"] == null ? null : Admission.fromJson(json["Admission"]),
    lapDance: json["Lap Dance"] == null ? null : Admission.fromJson(json["Lap Dance"]),
    tips: json["Tips"] == null ? null : Admission.fromJson(json["Tips"]),
    special: json["Special"] == null ? null : Admission.fromJson(json["Special"]),
  );

  Map<String, dynamic> toJson() => {
    "Admission": admission == null ? null : admission.toJson(),
    "Lap Dance": lapDance == null ? null : lapDance.toJson(),
    "Tips": tips == null ? null : tips.toJson(),
    "Special": special == null ? null : special.toJson(),
  };
}

class Admission {
  Admission({
    this.cost,
    this.rrp,
    this.price,
    this.inStock,
    this.onOrder,
    this.soldAmount,
    this.soldWorth,
  });

  int cost;
  int rrp;
  int price;
  int inStock;
  int onOrder;
  int soldAmount;
  int soldWorth;

  factory Admission.fromJson(Map<String, dynamic> json) => Admission(
    cost: json["cost"] == null ? null : json["cost"],
    rrp: json["rrp"] == null ? null : json["rrp"],
    price: json["price"] == null ? null : json["price"],
    inStock: json["in_stock"] == null ? null : json["in_stock"],
    onOrder: json["on_order"] == null ? null : json["on_order"],
    soldAmount: json["sold_amount"] == null ? null : json["sold_amount"],
    soldWorth: json["sold_worth"] == null ? null : json["sold_worth"],
  );

  Map<String, dynamic> toJson() => {
    "cost": cost == null ? null : cost,
    "rrp": rrp == null ? null : rrp,
    "price": price == null ? null : price,
    "in_stock": inStock == null ? null : inStock,
    "on_order": onOrder == null ? null : onOrder,
    "sold_amount": soldAmount == null ? null : soldAmount,
    "sold_worth": soldWorth == null ? null : soldWorth,
  };
}

class News {
  News({
    this.timestamp,
    this.news,
  });

  int timestamp;
  String news;

  factory News.fromJson(Map<String, dynamic> json) => News(
    timestamp: json["timestamp"] == null ? null : json["timestamp"],
    news: json["news"] == null ? null : json["news"],
  );

  Map<String, dynamic> toJson() => {
    "timestamp": timestamp == null ? null : timestamp,
    "news": news == null ? null : news,
  };
}

class EnumValues<T> {
  Map<String, T> map;
  Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    if (reverseMap == null) {
      reverseMap = map.map((k, v) => new MapEntry(v, k));
    }
    return reverseMap;
  }
}
