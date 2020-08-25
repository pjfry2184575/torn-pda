import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:torn_pda/models/company/company_model.dart';
import 'package:torn_pda/providers/user_details_provider.dart';
import 'package:torn_pda/utils/api_caller.dart';
import '../main.dart';

class CompanyPage extends StatefulWidget {
  @override
  _CompanyPageState createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {

  CompanyModel _company;
  DateTime _timeStamp;

  UserDetailsProvider _userProvider;

  Future _apiResult;
  bool _apiGoodData = false;
  int _apiErrorType = 0;
  int _apiRetries = 0;
  Timer _tickerCallApi;

  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<UserDetailsProvider>(context, listen: false);
    _apiResult = _fetchApi();
    _tickerCallApi = new Timer.periodic(Duration(seconds: 30), (Timer t) => _fetchApi());
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
      body: FutureBuilder(
          future: _apiResult,
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.data is CompanyModel) {
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("OK",
                        style: Theme.of(context).textTheme.bodyText2.copyWith(
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return _connectError();
              }
            } else {
              return Center(child: CircularProgressIndicator());
            }
          }),
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
        } else if (apiResponse is ApiError){
          _apiGoodData = false;
          _apiErrorType = apiResponse.errorId;
          _apiRetries = 0;
        }
      }
    });

  }

}
