# Development Guidelines & Constraints

This document outlines the technical constraints, architectural decisions, and specific coding rules to be followed during the development of the Walked app.

## Target Platforms
- **Primary:** iOS and Android.
- **Secondary (Postponed):** Web support will be developed in a later phase.

## Architecture & Storage
- **Offline-First:** All data (trips, POIs, notes, toggles) must be saved locally on the device first. The app must be fully functional without an internet connection.
- **Synchronization:** The app will sync with a remote server. The server-side implementation is postponed, but the local data models and architecture must be designed to support eventual synchronization.

## Coding Styles & Rules (Dart/Flutter)
*   **Naming (Variables and Methods):**
    *   Strict English naming. Highly descriptive. No single-letter variables.
    *   Variables representing lists/arrays must be singular and end with `List` (e.g., `userList`, not `users`).
    *   Asynchronous methods must have the `Async` suffix (e.g., `fetchDataAsync()`).
*   **Syntax and Formatting:**
    *   **Mandatory Braces & Multiline:** Use curly braces `{}` for all `if`, `for`, and `while` blocks, with **no exceptions** for single-line blocks. The body of the block (e.g. `return;`) must NEVER be on the same line as the condition; it must be wrapped in `{}` on a new line.
    *   **Condition Parentheses:** When writing multiple conditions with logical operators (e.g. `||` or `&&`), any condition that is not a direct boolean must be wrapped in parentheses. Example: `if ((item == null) || (item.latitude == null))`. Direct booleans like `if (!mounted)` are fine without extra parentheses.
    *   No spaces before structural keywords if preceded by a closing brace (e.g., `}else` and `}catch`, not `} else`).
    *   Line length limits are flexible (can exceed 80 characters).
    *   **Named Parameters Alignment:** When passing multiple named parameters to functions or constructors (e.g., UI widgets), their colons (`:`) must be vertically aligned using spaces to improve readability.
    *   **Conditional Collections (Spread Operator):** When conditionally adding elements inside UI collections (like lists of Widgets), ALWAYS use the spread operator syntax `if (condition) ...[ Widget ],` instead of a standalone `if (condition) Widget,`.
    *   **Method Chaining Indentation:** When chaining methods across multiple lines (e.g., builder patterns, database queries), indent the chained calls with exactly **2 spaces** relative to the root object. The final semicolon `;` must be placed on its own line, matching the root object's indentation.
        Example:
        ```dart
        return await _isar.tripItemModels
          .filter()
          .findAll()
        ;
        ```
*   **Class Properties:** Explicitly use the `this.` prefix to refer to public class properties. Do **NOT** use `this.` for private variables or methods (those starting with `_`).
*   **Comments & Code Structure:** All code comments must be written in English. Always add comments to important classes and functions, regardless of whether they are public or private. Separate long code blocks with important comments explaining what will be done. If a function or widget is too long, extract parts into private functions.
*   **No Magic Values:** Never use magic strings or magic numbers in the UI. Always use the localization system (`AppLocalizations`) for text and centralized constants (in `lib/constants/`) for padding, sizes, and colors.
*   **Imports:**
    *   Default UI import should be `import 'package:flutter/widgets.dart';` (avoid `material.dart` or `cupertino.dart` unless strictly necessary).
    *   Order of imports (separated by empty lines):
        1. `import 'dart:...'`
        2. `import 'package:...'`
        3. Local project imports.
    *   Within each group, sort imports by line length.
*   **Flutter Specifics:**
    *   Constructors: always use `this.propertyName` in the signature.
    *   State Widgets: inside `State` classes, access the widget properties using `widget` (NOT `this.widget`).
    *   Futures: omit the generic void, use `Future` instead of `Future<void>`.
    *   **Children Separation:** In any Widget that takes a `children` list (like `Column`, `Row`, `ListView`), separate each child with a comment explaining its purpose (e.g. `// Header title`).
*   **Project Structure (Strict Folders):**
    *   `pages/` (App screens). Group by domain/entity (e.g., `/pages/trip/trip.page.dart`, `/pages/trip/trip-create.page.dart`). Must follow the pattern: `/pages/domain/domain.page.dart` (Scaffold only) and `/pages/domain/widgets/domain.widget.dart` (Body content).
    *   `services/` (Business logic and APIs)
    *   `widgets/` (Reusable UI components)
    *   `database/` (Local data management)
*   **File Naming:** File names must strictly use kebab-case (`-`), never underscores (`_`). Example: `home-page.dart`.
*   Files must end with an empty line.

## Coding Styles & Rules (C# / Backend)
*   **No Generic New (`new()`):** Never use target-typed `new()`. Always explicitly specify the class name when instantiating objects (e.g. `new List<string>()` instead of `new()`, `new UserModel()` instead of `new()`).
*   **Format C# Like Dart:**
    *   Mandatory braces `{}` for all `if`, `for`, and `while` blocks (no single-line blocks).
    *   No spaces before structural keywords if preceded by a closing brace (e.g. `}else`, `}catch`, `}finally`).
    *   Asynchronous methods must have the `Async` suffix (e.g., `GetUserListAsync()`).
    *   Lists/arrays must be singular and end with `List` (e.g. `userList`).

## Git & Version Control
*   **No Automatic Commits / Push:** NEVER run `git commit` or `git push` automatically. Always leave code modifications staged/unstaged in the working tree and wait for the user to explicitly request a commit or push.

## Final Verification Rule
At the end of every task or request, before concluding your turn and sending the final message to the user, you MUST automatically:
1. Run the formatting scripts: dart run c:\Users\Fabio\source\nanna\nanna-flutter\bin\format-alignment.script.dart and dart run c:\Users\Fabio\source\nanna\nanna-flutter\bin\format-imports.script.dart.
2. Run lutter analyze.
3. Check that no hardcoded Colors. or CupertinoColors. were introduced. If any are found, replace them with AppColors constants.
4. **No Magic Strings Check**: Strictly verify that NO hardcoded text strings (e.g. Text('Errore')) were introduced in the UI. If any are found, you MUST add them to the .arb files and replace them with AppLocalizations before finishing.
Do not ask the user for permission to do this verification; do it proactively and fix any errors before considering the task done.

## Icons
*   **Always use NaIcons**: For all icons in the app, always use NaIcons (e.g. NaIcons.add) instead of manually instantiating Icon, CupertinoIcons, or NaIconData(...) directly, unless the icon is strictly missing from NaIcons.

## Comments
*   **English Comments**: All comments in the codebase MUST be written in English.

## Mindset & Execution Speed
*   **No Rushing**: Never rush through a task. Take all the necessary time and steps to implement the solution completely and correctly.
*   **Holistic Implementation**: Ensure all related parts of the system are updated (e.g., if a database model changes, update the UI, the map, the list, and check for unsaved changes logic).
*   **Strict Guideline Adherence**: Double-check every single line of code against the project guidelines (No Magic Strings, No Magic Values, Braces, Imports, etc.) before considering a task done.
*   **Formatting Check on Touch**: Whenever you touch (create or modify) a file, you MUST check and ensure that its entire contents are formatted according to the agreed style guide rules (braces, indentation, imports order, trailing commas, etc.).
