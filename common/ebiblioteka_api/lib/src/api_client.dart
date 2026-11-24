import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

/// Greska koju API vrati ili nastane pri komunikaciji. [message] je spreman za prikaz korisniku.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Datoteka za slanje (npr. slika) u multipart zahtjevu.
class UploadFile {
  UploadFile({required this.field, required this.filename, required this.bytes});

  final String field;
  final String filename;
  final List<int> bytes;
}

/// Tanak HTTP klijent: dodaje JWT token, pretvara greske u [ApiException] s porukom na bosanskom.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? client})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _http = client ?? http.Client();

  static const _timeout = Duration(seconds: 30);

  final String baseUrl;
  final http.Client _http;

  String? token;

  /// Poziva se kad server odbije token (istekao ili neispravan): aplikacija vodi korisnika na prijavu.
  void Function()? onUnauthorized;

  Map<String, String> get authHeaders => {if (token != null) 'Authorization': 'Bearer $token'};

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        params[key] = value.toString();
      }
    });
    return Uri.parse('$baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? query}) async {
    final response = await _guard(() => _http.get(uri(path, query), headers: authHeaders));
    _throwIfError(response);
    return response.bodyBytes;
  }

  /// multipart/form-data: polja i opcionalne datoteke (slike).
  Future<dynamic> sendMultipart(
    String method,
    String path, {
    Map<String, String> fields = const {},
    List<UploadFile> files = const [],
  }) async {
    final request = http.MultipartRequest(method, uri(path))
      ..headers.addAll(authHeaders)
      ..fields.addAll(fields);
    for (final file in files) {
      request.files.add(http.MultipartFile.fromBytes(
        file.field,
        file.bytes,
        filename: file.filename,
        contentType: _imageType(file.filename),
      ));
    }

    final response = await _guard(() async => http.Response.fromStream(await _http.send(request)));
    _throwIfError(response);
    return _decode(response);
  }

  /// Server prihvata samo PNG i JPEG, pa se tip slike određuje po ekstenziji naziva.
  static MediaType _imageType(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return MediaType('image', 'png');
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final response = await _guard(() {
      final headers = {...authHeaders, if (body != null) 'Content-Type': 'application/json'};
      final encoded = body == null ? null : jsonEncode(body);
      final target = uri(path, query);

      switch (method) {
        case 'GET':
          return _http.get(target, headers: headers);
        case 'POST':
          return _http.post(target, headers: headers, body: encoded);
        case 'PUT':
          return _http.put(target, headers: headers, body: encoded);
        case 'DELETE':
          return _http.delete(target, headers: headers);
      }
      throw ArgumentError('Nepodrzana metoda $method');
    });

    _throwIfError(response);
    return _decode(response);
  }

  Future<http.Response> _guard(Future<http.Response> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } on SocketException {
      throw ApiException('Server nije dostupan. Provjerite vezu i pokušajte ponovo.');
    } on TimeoutException {
      throw ApiException('Server ne odgovara. Pokušajte ponovo.');
    } on http.ClientException {
      throw ApiException('Server nije dostupan. Provjerite vezu i pokušajte ponovo.');
    }
  }

  dynamic _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    if (response.statusCode == 401 && token != null) {
      onUnauthorized?.call();
    }

    throw ApiException(_messageFrom(response), statusCode: response.statusCode);
  }

  String _messageFrom(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, dynamic>) {
        // Nasa greska: {status, message}
        if (json['message'] is String) {
          return json['message'] as String;
        }

        // Validacija ASP.NET-a: {errors: {Polje: [poruke]}}
        final errors = json['errors'];
        if (errors is Map<String, dynamic>) {
          for (final messages in errors.values) {
            if (messages is List && messages.isNotEmpty) {
              return messages.first.toString();
            }
          }
        }
      }
    } on FormatException {
      // Tijelo nije JSON: koristi se opca poruka ispod.
    }

    switch (response.statusCode) {
      case 401:
        return 'Niste prijavljeni ili je prijava istekla.';
      case 403:
        return 'Nemate pravo za ovu radnju.';
      case 404:
        return 'Traženi podatak nije pronađen.';
      default:
        return 'Došlo je do greške (${response.statusCode}).';
    }
  }
}
