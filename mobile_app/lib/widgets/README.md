# Form Widgets Documentation

This folder contains reusable form widgets that eliminate code duplication across the app's authentication screens.

## Available Widgets

### 1. GradientBackground

A reusable gradient background container with optional back button.

```dart
GradientBackground(
  showBackButton: true,
  onBackPressed: () => Navigator.pop(context), // Optional custom back action
  child: YourContent(),
)
```

### 2. FormCard

A white card container with shadow for form content.

```dart
FormCard(
  padding: EdgeInsets.all(24), // Optional custom padding
  child: YourFormContent(),
)
```

### 3. CustomTextFormField

A styled text form field with consistent theming.

```dart
CustomTextFormField(
  controller: _emailController,
  labelText: 'Email',
  hintText: 'Enter your email',
  prefixIcon: Icons.email_outlined,
  keyboardType: TextInputType.emailAddress,
  validator: (value) => value?.isEmpty == true ? 'Required' : null,
)
```

### 4. PasswordField

A password field with visibility toggle.

```dart
PasswordField(
  controller: _passwordController,
  labelText: 'Password',
  validator: (value) => value?.length < 6 ? 'Too short' : null,
)
```

### 5. CustomElevatedButton

A styled elevated button with loading state support.

```dart
CustomElevatedButton(
  text: 'Submit',
  onPressed: _handleSubmit,
  isLoading: _isLoading,
)
```

### 6. NavigationLink

A navigation link with leading text and clickable link.

```dart
NavigationLink(
  leadingText: "Don't have an account? ",
  linkText: 'Sign Up',
  onPressed: () => Navigator.push(context, ...),
)
```

### 7. FormHeader

A header with icon, title, and subtitle for form screens.

```dart
FormHeader(
  icon: Icons.person,
  title: 'Create Account',
  subtitle: 'Join us and start growing',
)
```

### 8. FormSectionHeader

A section header with title and description.

```dart
FormSectionHeader(
  title: 'Welcome',
  description: 'Login to your account',
)
```

### 9. TermsCheckbox

A checkbox for terms and conditions.

```dart
TermsCheckbox(
  value: _agreedToTerms,
  onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
  onTermsPressed: () => _showTermsDialog(),
)
```

### 10. ForgotPasswordLink

A "Forgot Password?" link.

```dart
ForgotPasswordLink(
  onPressed: () => Navigator.push(context, ...),
)
```

## Usage Example

Here's how to refactor an existing screen using these widgets:

### Before (Original Code):

```dart
// 200+ lines of repetitive code with manual styling
```

### After (Refactored Code):

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: GradientBackground(
      showBackButton: true,
      child: Column(
        children: [
          FormHeader(
            icon: Icons.lock_reset,
            title: 'Forgot Password?',
            subtitle: 'No worries, we\'ll help you reset it',
          ),
          FormCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  FormSectionHeader(
                    title: 'Reset Password',
                    description: 'Enter your email address...',
                  ),
                  CustomTextFormField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    prefixIcon: Icons.email_outlined,
                    validator: _validateEmail,
                  ),
                  SizedBox(height: 30),
                  CustomElevatedButton(
                    text: 'Send Reset Link',
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                  ),
                  NavigationLink(
                    leadingText: "Remember your password? ",
                    linkText: 'Back to Login',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

## Benefits

1. **Code Reduction**: Reduces form code by ~70%
2. **Consistency**: Ensures uniform styling across all forms
3. **Maintainability**: Changes to styling only need to be made in one place
4. **Reusability**: Easy to create new forms with consistent design
5. **Type Safety**: All widgets are properly typed with required parameters

## Import

To use these widgets, import the main form_widgets file:

```dart
import '../widgets/form_widgets.dart';
```

This will give you access to all the form widgets and their exports.

