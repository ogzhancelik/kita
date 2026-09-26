import 'package:flutter/material.dart';

/// Global RouteObserver that allows widgets (such as [DashboardMatchHistoryCard])
/// to observe route transitions (e.g., [RouteAware.didPopNext] when returning to the dashboard).
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
