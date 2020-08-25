import 'dart:async';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:torn_pda/models/company/company_model.dart';
import 'package:torn_pda/providers/user_details_provider.dart';
import 'package:torn_pda/utils/api_caller.dart';
import 'package:torn_pda/utils/html_parser.dart';
import '../main.dart';

class CompanyPage extends StatefulWidget {
  @override
  _CompanyPageState createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  CompanyModel _company;
  DateTime _timeStamp;

  UserDetailsProvider _userProvider;

  Future _apiFetched;
  bool _apiGoodData = false;
  int _apiErrorType = 0;
  int _apiRetries = 0;
  Timer _tickerCallApi;

  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<UserDetailsProvider>(context, listen: false);
    _apiFetched = _fetchApi();
    _tickerCallApi = new Timer.periodic(Duration(seconds: 45), (Timer t) => _fetchApi());
    analytics.logEvent(name: 'section_changed', parameters: {'section': 'company'});
  }

  @override
  void dispose() {
    _tickerCallApi.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Company'),
        leading: new IconButton(
          icon: new Icon(Icons.menu),
          onPressed: () {
            final ScaffoldState scaffoldState = context.findRootAncestorStateOfType();
            scaffoldState.openDrawer();
          },
        ),
      ),
      body: Container(
        child: FutureBuilder(
          future: _apiFetched,
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (_apiGoodData) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                        child: Column(
                          children: [
                            Text(
                              HtmlParser.fix(_company.company.name),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 5),
                            _starRating(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
                        child: _employees(),
                      ),
                      SizedBox(height: 50),
                    ],
                  ),
                );
              } else {
                return _connectError();
              }
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Container _starRating() {
    return Container(
      width: 55,
      height: 25,
      padding: EdgeInsets.all(0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.yellow[800],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_company.company.rating.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              )),
          SizedBox(width: 5),
          Icon(
            Icons.star,
            color: Colors.white,
            size: 16,
          )
        ],
      ),
    );
  }

  Card _employees() {
    var employeeLines = List<Widget>();
    int employeesOffline24Hours = 0;

    _company.company.employees.forEach((key, value) {
      var lastConnected = DateTime.fromMillisecondsSinceEpoch(value.lastAction.timestamp * 1000);
      var diffTime = DateTime.now().difference(lastConnected);

      Color diffColor = Colors.green;
      if (diffTime.inHours > 18) {
        employeesOffline24Hours++;
        diffColor = Colors.red;
      } else if (diffTime.inHours > 18) {
        diffColor = Colors.orange[700];
      }

      employeeLines.add(
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 2),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 120,
                child: Text(
                  value.name,
                ),
              ),
              Text(
                value.lastAction.relative,
                style: TextStyle(
                  color: diffColor,
                ),
              ),
            ],
          ),
        ),
      );
    });

    return Card(
      child: ExpandablePanel(
        header: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Text(
            'EMPLOYEES',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        collapsed: Padding(
          padding: const EdgeInsets.fromLTRB(25, 5, 20, 20),
          child: Text(
            'Offline 24h: $employeesOffline24Hours employees',
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        expanded: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: employeeLines,
          ),
        ),
      ),
    );
  }

  Widget _connectError() {
    String title = 'There was an error contacting the server!';
    String subtitle = 'Please try again later';

    if (_apiErrorType == 7) {
      title = 'Error: according to Torn, you don\'t have permissions to view these details (are '
          'you the owner of a company?)';
      subtitle = 'If you think this is a mistake or you just changed ownership, please reload your '
          'API Key (Settings section) or restart Torn PDA and try again';
    }

    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future _fetchApi() async {
    var apiResponse = await TornApiCaller.ownProfile(_userProvider.myUser.userApiKey).getCompany;

    setState(() {
      if (apiResponse is CompanyModel) {
        _apiRetries = 0;
        _company = apiResponse;
        _timeStamp = DateTime.fromMillisecondsSinceEpoch(_company.timestamp * 1000);
        _apiGoodData = true;
      } else {
        if (_apiGoodData && _apiRetries < 8) {
          _apiRetries++;
        } else if (apiResponse is ApiError) {
          _apiGoodData = false;
          _apiErrorType = apiResponse.errorId;
          _apiRetries = 0;
        }
      }
    });
  }
}
