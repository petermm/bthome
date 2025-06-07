# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-12-19

### Added
- Initial release of BTHome v2 protocol implementation for Elixir
- Complete support for all BTHome v2 sensor types and measurements
- Type-safe measurement creation and validation
- Binary serialization and deserialization of BTHome v2 packets
- Comprehensive error handling with structured error types
- Support for encrypted and trigger-based packets
- Full documentation with examples and API reference
- Extensive test suite with 168 tests covering all functionality
- Support for environmental sensors (temperature, humidity, pressure, etc.)
- Support for binary sensors (motion, door, window, etc.)
- Support for event sensors (button presses, dimmer events)
- Support for numeric sensors (energy, power, voltage, etc.)
- Validation of measurement values within sensor-specific ranges
- Graceful handling of unknown object IDs
- Both struct-based and map-based APIs for flexibility
- Dialyzer type checking and Credo code quality analysis

### Features
- 🔒 **Type Safety** - Uses structs for measurements and decoded data
- ✅ **Validation** - Comprehensive validation of measurement types and values
- 🚨 **Error Handling** - Structured errors with context information
- ⚡ **Performance** - Compile-time optimizations for fast lookups
- 🔄 **Compatibility** - Supports both struct and map-based APIs
- 📊 **Complete Coverage** - Supports all BTHome v2 sensor types
- 🛡️ **Error Recovery** - Graceful handling of unknown object IDs

[0.1.0]: https://github.com/petermm/bthome/releases/tag/v0.1.0