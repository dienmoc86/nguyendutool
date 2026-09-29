/// Motion effect for still images in video scenes (Ken Burns effect).
enum KenBurnsEffect {
  none,
  zoomIn,
  zoomOut,
  panLeft,
  panRight;

  String get displayName {
    switch (this) {
      case KenBurnsEffect.none:
        return 'Tĩnh (Không chuyển động)';
      case KenBurnsEffect.zoomIn:
        return 'Phóng to dần (Zoom In)';
      case KenBurnsEffect.zoomOut:
        return 'Thu nhỏ dần (Zoom Out)';
      case KenBurnsEffect.panLeft:
        return 'Lướt sang trái (Pan Left)';
      case KenBurnsEffect.panRight:
        return 'Lướt sang phải (Pan Right)';
    }
  }
}
