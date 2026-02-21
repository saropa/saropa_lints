# Dart SDK 3.9.2

## 3.9.2

**Released on:** 2025-08-27

### Tools

#### Development JavaScript compiler (DDC)

- Fixes an unintentional invocation of class static getters during a
  hot reload in a web development environment.
  This led to possible side effects being triggered early or
  crashes during the hot reload if the getter throws an exception.
