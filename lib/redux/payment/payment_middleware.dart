import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:invoiceninja_flutter/redux/app/app_actions.dart';
import 'package:invoiceninja_flutter/redux/app/app_middleware.dart';
import 'package:invoiceninja_flutter/redux/quote/quote_actions.dart';
import 'package:invoiceninja_flutter/ui/payment/refund/payment_refund_vm.dart';
import 'package:invoiceninja_flutter/utils/platforms.dart';
import 'package:redux/redux.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/redux/ui/ui_actions.dart';
import 'package:invoiceninja_flutter/ui/payment/payment_screen.dart';
import 'package:invoiceninja_flutter/ui/payment/edit/payment_edit_vm.dart';
import 'package:invoiceninja_flutter/ui/payment/view/payment_view_vm.dart';
import 'package:invoiceninja_flutter/redux/payment/payment_actions.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/data/repositories/payment_repository.dart';

List<Middleware<AppState>> createStorePaymentsMiddleware([
  PaymentRepository repository = const PaymentRepository(),
]) {
  final viewPaymentList = _viewPaymentList();
  final viewPayment = _viewPayment();
  final editPayment = _editPayment();
  final viewRefundPayment = _viewRefundPayment();
  final loadPayments = _loadPayments(repository);
  //final loadPayment = _loadPayment(repository);
  final savePayment = _savePayment(repository);
  final refundPayment = _refundPayment(repository);
  final archivePayment = _archivePayment(repository);
  final deletePayment = _deletePayment(repository);
  final restorePayment = _restorePayment(repository);
  final emailPayment = _emailPayment(repository);

  return [
    TypedMiddleware<AppState, ViewPaymentList>(viewPaymentList),
    TypedMiddleware<AppState, ViewPayment>(viewPayment),
    TypedMiddleware<AppState, EditPayment>(editPayment),
    TypedMiddleware<AppState, ViewRefundPayment>(viewRefundPayment),
    TypedMiddleware<AppState, LoadPayments>(loadPayments),
    //TypedMiddleware<AppState, LoadPayment>(loadPayment),
    TypedMiddleware<AppState, SavePaymentRequest>(savePayment),
    TypedMiddleware<AppState, RefundPaymentRequest>(refundPayment),
    TypedMiddleware<AppState, ArchivePaymentsRequest>(archivePayment),
    TypedMiddleware<AppState, DeletePaymentsRequest>(deletePayment),
    TypedMiddleware<AppState, RestorePaymentsRequest>(restorePayment),
    TypedMiddleware<AppState, EmailPaymentRequest>(emailPayment),
  ];
}

Middleware<AppState> _editPayment() {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as EditPayment;

    if (!action.force &&
        hasChanges(store: store, context: action.context, action: action)) {
      return;
    }

    next(action);

    store.dispatch(UpdateCurrentRoute(PaymentEditScreen.route));

    if (isMobile(action.context)) {
      action.navigator.pushNamed(PaymentEditScreen.route);
    }
  };
}

Middleware<AppState> _viewRefundPayment() {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as ViewRefundPayment;

    if (!action.force &&
        hasChanges(store: store, context: action.context, action: action)) {
      return;
    }

    next(action);

    if (isMobile(action.context)) {
      store.dispatch(UpdateCurrentRoute(PaymentRefundScreen.route));
      action.navigator.pushNamed(PaymentRefundScreen.route);
    } else {
      showDialog<PaymentRefundScreen>(
          context: action.context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return PaymentRefundScreen();
          });
    }
  };
}

Middleware<AppState> _viewPayment() {
  return (Store<AppState> store, dynamic action, NextDispatcher next) async {
    if (!action.force &&
        hasChanges(store: store, context: action.context, action: action)) {
      return;
    }

    next(action);

    store.dispatch(UpdateCurrentRoute(PaymentViewScreen.route));

    if (isMobile(action.context)) {
      action.navigator.pushNamed(PaymentViewScreen.route);
    }
  };
}

Middleware<AppState> _viewPaymentList() {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as ViewPaymentList;

    if (!action.force &&
        hasChanges(store: store, context: action.context, action: action)) {
      return;
    }

    next(action);

    if (store.state.isStale) {
      store.dispatch(RefreshData());
    }

    store.dispatch(UpdateCurrentRoute(PaymentScreen.route));

    if (isMobile(action.context)) {
      action.navigator.pushNamedAndRemoveUntil(
          PaymentScreen.route, (Route<dynamic> route) => false);
    }
  };
}

Middleware<AppState> _archivePayment(PaymentRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as ArchivePaymentsRequest;
    final prevPayments = action.paymentIds
        .map((id) => store.state.paymentState.map[id])
        .toList();
    repository
        .bulkAction(
            store.state.credentials, action.paymentIds, EntityAction.archive)
        .then((List<PaymentEntity> payments) {
      store.dispatch(ArchivePaymentsSuccess(payments));
      if (action.completer != null) {
        action.completer.complete(null);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(ArchivePaymentsFailure(prevPayments));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}

Middleware<AppState> _deletePayment(PaymentRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as DeletePaymentsRequest;
    final prevPayments = action.paymentIds
        .map((id) => store.state.paymentState.map[id])
        .toList();
    repository
        .bulkAction(
            store.state.credentials, action.paymentIds, EntityAction.delete)
        .then((List<PaymentEntity> payments) {
      store.dispatch(DeletePaymentsSuccess(payments));
      store.dispatch(RefreshData());
      if (action.completer != null) {
        action.completer.complete(null);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(DeletePaymentsFailure(prevPayments));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}

Middleware<AppState> _restorePayment(PaymentRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as RestorePaymentsRequest;
    final prevPayments = action.paymentIds
        .map((id) => store.state.paymentState.map[id])
        .toList();
    repository
        .bulkAction(
            store.state.credentials, action.paymentIds, EntityAction.restore)
        .then((List<PaymentEntity> payments) {
      store.dispatch(RestorePaymentsSuccess(payments));
      store.dispatch(RefreshData());
      if (action.completer != null) {
        action.completer.complete(null);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(RestorePaymentsFailure(prevPayments));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}

Middleware<AppState> _savePayment(PaymentRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as SavePaymentRequest;
    final PaymentEntity payment = action.payment;
    final bool sendEmail =
        payment.isNew ? store.state.prefState.emailPayment : false;
    repository
        .saveData(store.state.credentials, action.payment, sendEmail: sendEmail)
        .then((PaymentEntity payment) {
      if (action.payment.isNew) {
        store.dispatch(AddPaymentSuccess(payment));
      } else {
        store.dispatch(SavePaymentSuccess(payment));
      }
      store.dispatch(RefreshData());
      action.completer.complete(payment);
    }).catchError((Object error) {
      print(error);
      store.dispatch(SavePaymentFailure(error));
      action.completer.completeError(error);
    });

    next(action);
  };
}

Middleware<AppState> _refundPayment(PaymentRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as RefundPaymentRequest;
    final bool sendEmail = store.state.prefState.emailPayment;

    repository
        .refundPayment(store.state.credentials, action.payment,
            sendEmail: sendEmail)
        .then((PaymentEntity payment) {
      store.dispatch(SavePaymentSuccess(payment));
      store.dispatch(RefundPaymentSuccess(payment));
      store.dispatch(RefreshData());
      action.completer.complete(payment);
    }).catchError((Object error) {
      print(error);
      store.dispatch(RefundPaymentFailure(error));
      action.completer.completeError(error);
    });

    next(action);
  };
}

Middleware<AppState> _emailPayment(PaymentRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as EmailPaymentRequest;
    repository
        .saveData(store.state.credentials, action.payment, sendEmail: true)
        .then((PaymentEntity payment) {
      store.dispatch(SavePaymentSuccess(payment));
      action.completer.complete(null);
    }).catchError((Object error) {
      print(error);
      store.dispatch(SavePaymentFailure(error));
      action.completer.completeError(error);
    });

    next(action);
  };
}

/*
Middleware<AppState> _loadPayment(PaymentRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final AppState state = store.state;

    if (state.isLoading) {
      next(action);
      return;
    }

    store.dispatch(LoadPaymentRequest());
    repository
        .loadItem(store.state.credentials, action.paymentId)
        .then((payment) {
      store.dispatch(LoadPaymentSuccess(payment));

      if (action.completer != null) {
        action.completer.complete(null);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(LoadPaymentFailure(error));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}
*/

Middleware<AppState> _loadPayments(PaymentRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as LoadPayments;
    final AppState state = store.state;

    if (state.isLoading) {
      next(action);
      return;
    }

    store.dispatch(LoadPaymentsRequest());
    repository.loadList(store.state.credentials).then((data) {
      store.dispatch(LoadPaymentsSuccess(data));

      if (action.completer != null) {
        action.completer.complete(null);
      }
      store.dispatch(LoadQuotes());
    }).catchError((Object error) {
      print(error);
      store.dispatch(LoadPaymentsFailure(error));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}
