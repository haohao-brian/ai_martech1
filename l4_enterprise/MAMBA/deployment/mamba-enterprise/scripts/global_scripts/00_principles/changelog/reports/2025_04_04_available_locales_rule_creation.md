# Available Locales Rule Creation Record

## Overview

Created the Available Locales Rule (R36) to systematically manage and document available locales for consistent language support throughout the system.

## Motivation

The application requires clear guidance on how to determine available locales across different operating systems, manage locale configuration, implement locale support in the UI, and provide a reliable locale selection mechanism.

## Changes Made

1. Created new rule file `R36_available_locales.md` with the following sections:
   - Core requirement statement
   - Locale availability determination methods
   - Locale configuration management requirements
   - Locale implementation requirements
   - Locale selection mechanism specifications
   - Implementation examples with code samples
   - Common errors and solutions
   - Relationship to other principles
   - Benefits and conclusion

2. Established relationships with:
   - MP23: Language Preferences Meta-Principle (implements)
   - R34: UI Text Standardization Rule (related_to)
   - R17: Language Standard Adherence Rule (related_to)

3. Specified exact locale identifiers:
   - "en_US.UTF-8" for US English
   - "zh_TW.UTF-8" for Traditional Chinese (Taiwan)
   - Added human-readable display names for the UI selector

## Implementation Details

The rule provides specific guidance on:
- Using the POSIX shell command `locale -a` on Unix-like systems
- Platform-dependent interpretation of available locales
- Central definition of supported locales
- Verification mechanisms for locale availability
- Fallback strategies for unavailable locales
- UI terminology dictionary requirements
- Validation processes for translations
- User and administrator configuration options

## Expected Impact

This rule will enhance the application's internationalization capabilities by:
1. Ensuring consistent language support across components
2. Reducing runtime errors related to missing locales
3. Making locale availability explicitly verifiable
4. Supporting deployment across diverse environments
5. Improving the user experience through reliable language selection

## Next Steps

1. Implement the locale availability check function
2. Update application configuration to include locale settings
3. Create a locale selection UI component
4. Document system locale requirements in deployment documentation