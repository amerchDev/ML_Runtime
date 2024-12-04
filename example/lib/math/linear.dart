import 'dart:ui';

(double, double) regression(Iterable<Offset> offsets) {
  double m_x = 0, m_y = 0;
  double sum_xy = 0, sum_xx = 0;

  for (var obj in offsets) {
    m_x += obj.dx;
    m_y += obj.dy;
    sum_xy += obj.dx * obj.dy;
    sum_xx += obj.dx * obj.dx;
  }
  m_x /= offsets.length;
  m_y /= offsets.length;

  double SS_xy = sum_xy - offsets.length * m_y * m_x;
  double SS_xx = sum_xx - offsets.length * m_x * m_x;

  double m = SS_xy / SS_xx;
  double b = m_y - m * m_x;
  return (m, b);
}
