import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// App Exception Types
enum AppErrorType {
  network,
  authentication,
  permission,
  notFound,
  validation,
  server,
  timeout,
  unknown,
  offline,
  rateLimited,
}

/// Custom App Exception
class AppException implements Exception {
  final String message;
  final String? code;
  final AppErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.code,
    this.type = AppErrorType.unknown,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException[$type]: $message (code: $code)';

  /// Get user-friendly error message
  String get userMessage {
    switch (type) {
      case AppErrorType.network:
        return 'Network error. Please check your internet connection.';
      case AppErrorType.authentication:
        return 'Authentication failed. Please login again.';
      case AppErrorType.permission:
        return 'You don\'t have permission to perform this action.';
      case AppErrorType.notFound:
        return 'The requested resource was not found.';
      case AppErrorType.validation:
        return message;
      case AppErrorType.server:
        return 'Server error. Please try again later.';
      case AppErrorType.timeout:
        return 'Request timed out. Please try again.';
      case AppErrorType.offline:
        return 'You are offline. Some features may not be available.';
      case AppErrorType.rateLimited:
        return 'Too many requests. Please wait a moment.';
      case AppErrorType.unknown:
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get icon for error type
  IconData get icon {
    switch (type) {
      case AppErrorType.network:
      case AppErrorType.offline:
        return Icons.wifi_off;
      case AppErrorType.authentication:
        return Icons.lock_outline;
      case AppErrorType.permission:
        return Icons.block;
      case AppErrorType.notFound:
        return Icons.search_off;
      case AppErrorType.validation:
        return Icons.warning_amber;
      case AppErrorType.server:
        return Icons.cloud_off;
      case AppErrorType.timeout:
        return Icons.timer_off;
      case AppErrorType.rateLimited:
        return Icons.speed;
      case AppErrorType.unknown:
      default:
        return Icons.error_outline;
    }
  }
}

/// Error Handling Service
class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  final _errorStreamController = StreamController<AppException>.broadcast();
  Stream<AppException> get errorStream => _errorStreamController.stream;

  /// Parse and convert any exception to AppException
  AppException parseError(dynamic error, [StackTrace? stackTrace]) {
    

    if (error is AppException) {
      return error;
    }

    if (error is FirebaseException) {
      return _parseFirebaseError(error, stackTrace);
    }

    if (error is SocketException) {
      return AppException(
        message: 'Network connection failed',
        type: AppErrorType.network,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is TimeoutException) {
      return AppException(
        message: 'Request timed out',
        type: AppErrorType.timeout,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return AppException(
        message: 'Invalid data format',
        type: AppErrorType.validation,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Check for specific error messages
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('permission') || errorString.contains('denied')) {
      return AppException(
        message: 'Permission denied',
        type: AppErrorType.permission,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('not found') || errorString.contains('404')) {
      return AppException(
        message: 'Resource not found',
        type: AppErrorType.notFound,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('unauthorized') ||
        errorString.contains('unauthenticated') ||
        errorString.contains('401')) {
      return AppException(
        message: 'Authentication required',
        type: AppErrorType.authentication,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('internet')) {
      return AppException(
        message: 'Network error',
        type: AppErrorType.network,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return AppException(
      message: error.toString(),
      type: AppErrorType.unknown,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  AppException _parseFirebaseError(FirebaseException error, StackTrace? stackTrace) {
    AppErrorType type;
    String message = error.message ?? 'Firebase error';

    switch (error.code) {
      case 'permission-denied':
        type = AppErrorType.permission;
        message = 'You don\'t have permission for this action';
        break;
      case 'not-found':
        type = AppErrorType.notFound;
        message = 'Document not found';
        break;
      case 'unavailable':
        type = AppErrorType.offline;
        message = 'Service temporarily unavailable';
        break;
      case 'cancelled':
        type = AppErrorType.timeout;
        message = 'Operation was cancelled';
        break;
      case 'resource-exhausted':
        type = AppErrorType.rateLimited;
        message = 'Quota exceeded';
        break;
      case 'unauthenticated':
        type = AppErrorType.authentication;
        message = 'Please login to continue';
        break;
      default:
        type = AppErrorType.server;
    }

    return AppException(
      message: message,
      code: error.code,
      type: type,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handle error and show UI feedback
  void handleError(
    BuildContext context,
    dynamic error, {
    StackTrace? stackTrace,
    String? customMessage,
    VoidCallback? onRetry,
    bool showSnackBar = true,
  }) {
    final appError = parseError(error, stackTrace);

    // Log error
    
    if (appError.stackTrace != null) {
      
    }

    // Emit to stream for global listeners
    _errorStreamController.add(appError);

    // Show UI feedback
    if (showSnackBar && context.mounted) {
      _showErrorSnackBar(
        context,
        customMessage ?? appError.userMessage,
        appError,
        onRetry,
      );
    }
  }

  void _showErrorSnackBar(
    BuildContext context,
    String message,
    AppException error,
    VoidCallback? onRetry,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error.icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: onRetry != null ? 5 : 3),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  Color _getErrorColor(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
      case AppErrorType.offline:
        return Colors.orange.shade700;
      case AppErrorType.authentication:
      case AppErrorType.permission:
        return Colors.red.shade700;
      case AppErrorType.validation:
        return Colors.amber.shade700;
      case AppErrorType.timeout:
      case AppErrorType.rateLimited:
        return Colors.blue.shade700;
      default:
        return Colors.red.shade700;
    }
  }

  /// Show error dialog for critical errors
  void showErrorDialog(
    BuildContext context,
    AppException error, {
    String? title,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(error.icon, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(
              title ?? 'Error',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          error.userMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDismiss?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Execute function with error handling
  Future<T?> tryAsync<T>(
    Future<T> Function() action, {
    BuildContext? context,
    String? errorMessage,
    VoidCallback? onError,
    VoidCallback? onRetry,
    T? defaultValue,
  }) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      

      if (context != null && context.mounted) {
        handleError(
          context,
          e,
          stackTrace: stackTrace,
          customMessage: errorMessage,
          onRetry: onRetry,
        );
      }

      onError?.call();
      return defaultValue;
    }
  }

  /// Dispose
  void dispose() {
    _errorStreamController.close();
  }
}

/// Result wrapper for operations
class Result<T> {
  final T? data;
  final AppException? error;
  final bool isSuccess;

  Result.success(this.data)
      : error = null,
        isSuccess = true;

  Result.failure(this.error)
      : data = null,
        isSuccess = false;

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data as T);
    } else {
      return failure(error!);
    }
  }
}

/// Global error handler mixin
mixin ErrorHandlerMixin<T extends StatefulWidget> on State<T> {
  final ErrorHandlingService _errorService = ErrorHandlingService();

  void handleError(dynamic error, {String? message, VoidCallback? onRetry}) {
    if (mounted) {
      _errorService.handleError(
        context,
        error,
        customMessage: message,
        onRetry: onRetry,
      );
    }
  }

  Future<R?> safeAsync<R>(
    Future<R> Function() action, {
    String? errorMessage,
    VoidCallback? onRetry,
    R? defaultValue,
  }) {
    return _errorService.tryAsync(
      action,
      context: context,
      errorMessage: errorMessage,
      onRetry: onRetry,
      defaultValue: defaultValue,
    );
  }
}
