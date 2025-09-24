import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

class SecureHttpClient {
  static final SecureHttpClient _instance = SecureHttpClient._internal();
  late final http.Client _client;
  
  factory SecureHttpClient() => _instance;
  
  SecureHttpClient._internal() {
    _client = _createSecureClient();
  }
  
  http.Client _createSecureClient() {
    if (kIsWeb) {
      // Web doesn't support SecurityContext
      return http.Client();
    }
    
    // For mobile/desktop platforms
    final client = HttpClient();
    
    // Configure security settings
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // For production, implement proper certificate validation
      // For now, we validate the host is trusted
      return _isTrustedHost(host);
    };
    
    // Set secure connection parameters
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 60);
    
    return IOClient(client);
  }
  
  bool _isTrustedHost(String host) {
    // List of trusted hosts for API calls
    const trustedHosts = [
      'generativelanguage.googleapis.com',
      'googleapis.com',
      'google.com',
    ];
    
    return trustedHosts.any((trustedHost) => 
        host == trustedHost || host.endsWith('.$trustedHost'));
  }
  
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    // Add security headers
    final secureHeaders = {
      'User-Agent': 'QualityControl-Mobile/1.0',
      'Accept': 'application/json',
      'Connection': 'close',
      ...?headers,
    };
    
    // Validate URL is HTTPS
    if (url.scheme != 'https') {
      throw SecurityException('Only HTTPS connections are allowed: ${url.scheme}');
    }
    
    // Validate host is trusted
    if (!_isTrustedHost(url.host)) {
      throw SecurityException('Untrusted host: ${url.host}');
    }
    
    try {
      final response = await _client.get(url, headers: secureHeaders)
          .timeout(const Duration(seconds: 30));
      
      // Validate response
      _validateResponse(response);
      
      return response;
    } on SocketException catch (e) {
      throw NetworkException('Network connection failed: ${e.message}');
    } on HandshakeException catch (e) {
      throw SecurityException('SSL/TLS handshake failed: ${e.message}');
    } catch (e) {
      throw HttpException('HTTP request failed: $e');
    }
  }
  
  Future<http.Response> post(Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    // Add security headers
    final secureHeaders = {
      'User-Agent': 'QualityControl-Mobile/1.0',
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      'Connection': 'close',
      ...?headers,
    };
    
    // Validate URL is HTTPS
    if (url.scheme != 'https') {
      throw SecurityException('Only HTTPS connections are allowed: ${url.scheme}');
    }
    
    // Validate host is trusted
    if (!_isTrustedHost(url.host)) {
      throw SecurityException('Untrusted host: ${url.host}');
    }
    
    try {
      final response = await _client.post(
        url, 
        headers: secureHeaders, 
        body: body,
        encoding: encoding
      ).timeout(const Duration(seconds: 180)); // 3 minutes for image analysis
      
      // Validate response
      _validateResponse(response);
      
      return response;
    } on SocketException catch (e) {
      throw NetworkException('Network connection failed: ${e.message}');
    } on HandshakeException catch (e) {
      throw SecurityException('SSL/TLS handshake failed: ${e.message}');
    } catch (e) {
      throw HttpException('HTTP request failed: $e');
    }
  }
  
  void _validateResponse(http.Response response) {
    // Check for suspicious headers or content
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success - validate content type for JSON endpoints
      if (!contentType.contains('application/json') && 
          !contentType.contains('text/plain')) {
        // Log warning but don't fail - some APIs may return different content types
        debugPrint('Warning: Unexpected content-type: $contentType');
      }
    }
    
    // Check content length is reasonable (max 10MB for API responses)
    final contentLength = response.contentLength ?? response.bodyBytes.length;
    if (contentLength > 10 * 1024 * 1024) {
      throw SecurityException('Response too large: ${contentLength} bytes');
    }
  }
  
  void dispose() {
    _client.close();
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  
  @override
  String toString() => 'HttpException: $message';
}