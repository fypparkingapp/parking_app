part of 'navigation_screen.dart';

/// User-selected priorities for sorting routes (first = primary).
enum RouteSortKey { time, distance, price }

typedef _AnnotatedRoute = ({routing.RouteResult route, TollEstimate toll});

enum TollTimeMode { now, departAt, arriveBy }
