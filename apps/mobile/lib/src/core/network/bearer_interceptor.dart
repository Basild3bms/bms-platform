import 'package:dio/dio.dart';

class BearerInterceptor extends Interceptor {
  BearerInterceptor(this._token);

  final String? Function() _token;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _token();
    if (token == null ||
        token.isEmpty ||
        token.contains('\n') ||
        token.contains('\r')) {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
        type: DioExceptionType.badResponse,
      ));
      return;
    }
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
