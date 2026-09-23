import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Reusable avatar widget that reliably renders:
/// 1. Remote HTTP/HTTPS images from Supabase Storage or external providers
/// 2. Base64 Data URI strings (e.g. data:image/jpeg;base64,...)
/// 3. Offline/empty fallback to the default senior portrait or icon avatar
class DdAvatar extends StatelessWidget {
  const DdAvatar({
    super.key,
    this.avatarUrl,
    this.size = 56.0,
    this.borderColor = Colors.white,
    this.borderWidth = 2.5,
    this.showShadow = true,
  });

  final String? avatarUrl;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final bool showShadow;

  static const String defaultPortraitUrl =
      'https://lh3.googleusercontent.com/a/ACg8ocL8J4aP9u_3n2H7tY0L8vQ4mZk7X9p5w8s2j1d0=s96-c';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final commaIdx = url.indexOf(',');
          if (commaIdx != -1) {
            final base64Str = url.substring(commaIdx + 1);
            final Uint8List bytes = base64Decode(base64Str);
            return Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallback(),
            );
          }
        } catch (_) {}
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        return Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      }
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Image.network(
      defaultPortraitUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFFFDAD9),
        child: Center(
          child: Icon(
            Icons.person_rounded,
            size: size * 0.55,
            color: const Color(0xFFB1002C),
          ),
        ),
      ),
    );
  }
}
