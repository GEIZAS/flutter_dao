library flutter_dao;

import 'dart:convert';
import "package:http/http.dart" as http;

//** ENUMS
enum RequestMethod {
  Get,
  Post,
  Put,
  Delete,
}

enum NetworkStatusCode {
  OK,
  NoResponse,
  BadRequest,
  InternalServerError,
  NotAcceptable,
  Unauthorized,
  NoServiceConnection, // ?
  Client_ParseError, // ?
  Request_BadRequest, // ?
  ImageDownload, // ?
  NoContent,
  Unknown, // ?
  NoInternetConnection,
}

class DaoError {
  NetworkStatusCode type;
  String message;

  static Map<NetworkStatusCode, String> _typeMessageMap = {
    NetworkStatusCode.NoContent: 'No Content',
    NetworkStatusCode.BadRequest: 'Bad Request',
    NetworkStatusCode.Unauthorized: 'Unauthorized',
    NetworkStatusCode.NotAcceptable: 'Not Acceptable',
    NetworkStatusCode.NoResponse: 'No Response',
    NetworkStatusCode.InternalServerError: 'Internal Server Error',
    NetworkStatusCode.NoInternetConnection: 'İnternet bağlantısı yok',
  };

  static final Map<int, NetworkStatusCode> codeTypeMap = {
    204: NetworkStatusCode.NoContent,
    400: NetworkStatusCode.BadRequest,
    401: NetworkStatusCode.Unauthorized,
    406: NetworkStatusCode.NotAcceptable,
    444: NetworkStatusCode.NoResponse,
    500: NetworkStatusCode.InternalServerError,
    600: NetworkStatusCode.NoInternetConnection,
  };

  DaoError(this.type, this.message);

  DaoError.withType(NetworkStatusCode type) : this(type, _typeMessageMap[type]);

  DaoError.withCode(int code) : this.withType(codeTypeMap[code]);
}

// INTERFACES
abstract class DaoListener {
  void daoDidSuccess(Dao dao, Object data);
  void daoDidFail(Dao dao, DaoError statusCode);
}

abstract class Dao {
  String _url;
  RequestMethod _method;
  Map<String, String> headers = Map();
  Map<String, String> urlParams = Map();
  Object body;
  DaoListener _listener;

  String get _finalUrl {
    String result = this._url;
    this.urlParams.forEach((key, value) {
      result += "&" + key + "=";
      result += Uri.encodeQueryComponent(value);
    });
    result.replaceFirst(RegExp(r'&'), '?', 1);
    return result;
  }

  // Constructer
  Dao(this._url, this._method, this._listener);

  Future<void> execute() async {
    http.Response response;
    if (this._method == RequestMethod.Get) {
      response = await http.get(this._finalUrl, headers: this.headers);
    } else if (this._method == RequestMethod.Post) {
      response = await http.post(this._finalUrl,
          headers: this.headers, body: this.body);
    } else if (this._method == RequestMethod.Put) {
      response = await http.put(this._finalUrl,
          headers: this.headers, body: this.body);
    } else if (this._method == RequestMethod.Delete) {
      response = await http.delete(this._finalUrl, headers: this.headers);
    }

    DaoError error = this.handleError(response);

    if (error == null) {
      Object data = jsonDecode(response.body);
      if (data != null && (data is Map || data is List))
        this.onAfterSuccessRequest(data);
      else
        this.onAfterFailedRequest(
          DaoError.withType(NetworkStatusCode.NoContent),
        );
    } else {
      this.onAfterFailedRequest(error);
    }
  }

  DaoError handleError(http.Response response) {
    if (response.statusCode > 202) {
      return DaoError.withCode(response.statusCode);
    }
    return null;
  }

  void onAfterSuccessRequest(Object data) {
    this._listener?.daoDidSuccess(this, data);
  }

  void onAfterFailedRequest(DaoError error) {
    this._listener?.daoDidFail(this, error);
  }
}
