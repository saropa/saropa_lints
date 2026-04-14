// ignore_for_file: unused_element
// Fixture for prefer_impl_suffix: class implementing interface should end with Impl.

abstract class IRepo {}

// LINT: implements without Impl suffix
class MyRepo implements IRepo {}

// OK
class RepoImpl implements IRepo {}
