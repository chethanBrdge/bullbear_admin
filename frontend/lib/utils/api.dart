import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class API {
  final Dio _dio = Dio();

  String urlprefix = "http://ec2-56-228-15-3.eu-north-1.compute.amazonaws.com";

  API() {
    _dio.options.baseUrl = urlprefix;
    _dio.options.headers = {"Content-Type": "application/json"};
    _dio.interceptors.add(PrettyDioLogger());

    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return client;
      };
    }
  }

  Dio get sendRequest => _dio;
}
