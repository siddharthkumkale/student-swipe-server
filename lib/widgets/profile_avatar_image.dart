import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shows a profile photo from either a URL (http/https) or a data URL (base64).
/// Use this so photos work without Firebase Storage (free data-URL fallback).
class ProfileAvatarImage extends StatelessWidget {
  final String? photoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function()? placeholder;
  final Widget Function()? errorWidget;

  const ProfileAvatarImage({
    super.key,
    required this.photoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return _placeholderOrError(placeholder ?? _defaultPlaceholder);
    }

    if (photoUrl!.startsWith('data:image')) {
      return _buildDataUrlImage();
    }

    return CachedNetworkImage(
      imageUrl: photoUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => _placeholderOrError(placeholder ?? _defaultPlaceholder),
      errorWidget: (_, __, ___) => _placeholderOrError(errorWidget ?? _defaultPlaceholder),
    );
  }

  Widget _buildDataUrlImage() {
    try {
      final parts = photoUrl!.split(RegExp(r'base64,'));
      final base64 = parts.length > 1 ? parts.last : '';
      if (base64.isEmpty) return _placeholderOrError(errorWidget ?? _defaultPlaceholder);
      final bytes = base64Decode(base64);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholderOrError(errorWidget ?? _defaultPlaceholder),
      );
    } catch (_) {
      return _placeholderOrError(errorWidget ?? _defaultPlaceholder);
    }
  }

  Widget _placeholderOrError(Widget Function() builder) {
    return SizedBox(
      width: width,
      height: height,
      child: builder(),
    );
  }

  static Widget _defaultPlaceholder() => const Center(
        child: Icon(Icons.person_rounded, size: 48, color: Colors.white54),
      );
}
