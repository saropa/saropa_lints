// ignore_for_file: unused_field, unused_element, prefer_typing_uninitialized_variables

import 'dart:async';

import 'package:flutter/material.dart';

/// Test fixture for prefer_async_callback rule.
///
/// This rule warns when VoidCallback is used for callbacks that likely
/// perform async operations (based on naming patterns like onSubmit, onSave, etc.)

// BAD: Field declarations with async-suggesting names
class BadFieldExamples {
  // expect_lint: prefer_async_callback
  final VoidCallback? onSubmit;

  // expect_lint: prefer_async_callback
  final VoidCallback? onSave;

  // expect_lint: prefer_async_callback
  final VoidCallback? onLoad;

  // expect_lint: prefer_async_callback
  final VoidCallback? onFetch;

  // expect_lint: prefer_async_callback
  final VoidCallback? onRefresh;

  // expect_lint: prefer_async_callback
  final VoidCallback? onSync;

  // expect_lint: prefer_async_callback
  final VoidCallback? onUpload;

  // expect_lint: prefer_async_callback
  final VoidCallback? onDownload;

  // expect_lint: prefer_async_callback
  final VoidCallback? onLogin;

  // expect_lint: prefer_async_callback
  final VoidCallback? onLogout;

  // expect_lint: prefer_async_callback
  final VoidCallback? onDelete;

  // expect_lint: prefer_async_callback
  final VoidCallback? onExport;

  // expect_lint: prefer_async_callback
  final VoidCallback? onImport;

  // expect_lint: prefer_async_callback
  final VoidCallback? onValidate;

  // expect_lint: prefer_async_callback
  final VoidCallback? onConfirm;

  BadFieldExamples({
    this.onSubmit,
    this.onSave,
    this.onLoad,
    this.onFetch,
    this.onRefresh,
    this.onSync,
    this.onUpload,
    this.onDownload,
    this.onLogin,
    this.onLogout,
    this.onDelete,
    this.onExport,
    this.onImport,
    this.onValidate,
    this.onConfirm,
  });
}

// BAD: Parameter declarations with async-suggesting names
class BadParameterExamples {
  // expect_lint: prefer_async_callback
  void methodWithSubmit(VoidCallback? onSubmit) {}

  // expect_lint: prefer_async_callback
  void methodWithSave(VoidCallback onSave) {}

  // expect_lint: prefer_async_callback
  void methodWithLoad(VoidCallback? onLoad) {}
}

// BAD: Prefixed names should also be caught
class BadPrefixedNameExamples {
  // expect_lint: prefer_async_callback
  final VoidCallback? onSubmitForm;

  // expect_lint: prefer_async_callback
  final VoidCallback? onSaveData;

  // expect_lint: prefer_async_callback
  final VoidCallback? onLoadUser;

  // expect_lint: prefer_async_callback
  final VoidCallback? onFetchItems;

  // expect_lint: prefer_async_callback
  final VoidCallback? onDeleteAccount;

  BadPrefixedNameExamples({
    this.onSubmitForm,
    this.onSaveData,
    this.onLoadUser,
    this.onFetchItems,
    this.onDeleteAccount,
  });
}

// GOOD: Using AsyncCallback for async operations
class GoodAsyncCallbackExamples {
  final AsyncCallback? onSubmit;
  final AsyncCallback? onSave;
  final AsyncCallback? onLoad;
  final AsyncCallback? onFetch;
  final AsyncCallback? onRefresh;

  GoodAsyncCallbackExamples({
    this.onSubmit,
    this.onSave,
    this.onLoad,
    this.onFetch,
    this.onRefresh,
  });
}

// GOOD: VoidCallback for non-async operations
class GoodVoidCallbackExamples {
  final VoidCallback? onPressed; // Typical UI action, not async-suggesting
  final VoidCallback? onTap;
  final VoidCallback? onChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onClose;
  final VoidCallback? onDismiss;
  final VoidCallback? onToggle;
  final VoidCallback? onSelect;
  final VoidCallback? onClick;
  final VoidCallback? onFocus;
  final VoidCallback? onHover;

  GoodVoidCallbackExamples({
    this.onPressed,
    this.onTap,
    this.onChanged,
    this.onCancel,
    this.onClose,
    this.onDismiss,
    this.onToggle,
    this.onSelect,
    this.onClick,
    this.onFocus,
    this.onHover,
  });
}

// GOOD: Custom function types for async
class GoodCustomFunctionTypes {
  final Future<void> Function()? onSubmit;
  final Future<bool> Function()? onSave;
  final Future<void> Function()? onLoad;

  GoodCustomFunctionTypes({
    this.onSubmit,
    this.onSave,
    this.onLoad,
  });
}
