import 'dart:convert';
import 'package:apod/features/shared/models/models.dart';
import 'package:apod/features/shared/extensions.dart';
import 'package:chopper/chopper.dart';
import 'result.dart';

class ApodConverter implements Converter {
  @override
  Request convertRequest(Request request) {
    Map<String, dynamic> parameters = request.parameters;

    if (parameters['date'] is DateTime) {
      parameters['date'] = (parameters['date'] as DateTime).dateString();
    }
    if (parameters['start_date'] is DateTime) {
      parameters['start_date'] =
          (parameters['start_date'] as DateTime).dateString();
    }
    if (parameters['end_date'] is DateTime) {
      parameters['end_date'] =
          (parameters['end_date'] as DateTime).dateString();
    }

    final req = applyHeader(
      request,
      contentTypeKey,
      jsonHeaders,
      override: false,
    ).copyWith(parameters: parameters);

    return encodeJson(req);
  }

  Request encodeJson(Request request) {
    final contentType = request.headers[contentTypeKey];
    if (contentType != null && contentType.contains(jsonHeaders)) {
      return request.copyWith(body: json.encode(request.body));
    }
    return request;
  }

  Response<BodyType> decodeJson<BodyType, InnerType>(Response response) {
    final contentType = response.headers[contentTypeKey];
    var body = response.body;
    if (contentType != null && contentType.contains(jsonHeaders)) {
      body = utf8.decode(response.bodyBytes);
    }
    try {
      var rawResponse = json.decode(body);

      if (rawResponse is Map) {
        // Called `detail(...)`
        rawResponse['id'] = rawResponse['date'];
        return response.copyWith<BodyType>(
          body: Success(
            Apod.fromJson(
              {
                ...rawResponse,
                'id': rawResponse['date'],
              }.cast<String, dynamic>(),
            ),
          ) as BodyType,
        );
      } else if (rawResponse is List) {
        // Called `list(...)`
        return response.copyWith<BodyType>(
          body: Success(rawResponse
              .map<Apod>(
                (json) => Apod.fromJson(
                    {...json, 'id': json['date']}.cast<String, dynamic>()),
              )
              .toList()) as BodyType,
        );
      } else {
        return response.copyWith<BodyType>(
          body: Error(Exception('Unable to parse response')) as BodyType,
        );
      }
    } catch (e) {
      chopperLogger.warning(e);
      return response.copyWith<BodyType>(
          body: Error(e as Exception) as BodyType);
    }
  }

  @override
  Response<BodyType> convertResponse<BodyType, InnerType>(Response response) =>
      decodeJson<BodyType, InnerType>(response);
}
