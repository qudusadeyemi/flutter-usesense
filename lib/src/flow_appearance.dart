/// White-label customization contract for the Flows runner.
///
/// [FlowAppearance] (visual theming) and [FlowCopy] (subject-facing strings)
/// mirror the shared cross-SDK contract. Both are optional and supplied at SDK
/// init via [UseSenseFlows.runFlow]; the native runner merges them
/// SDK-init > server(branding) > built-in default.
///
/// Every field is optional. Each class exposes [toMap], which emits the
/// camelCase wire shape the native iOS/Android runners decode (iOS via
/// `JSONDecoder`, Android via `FlowAppearance.decode` / `FlowCopy.decode`).
/// Null fields are omitted so an unset override never blanks the native default.
library;

// ─── FlowAppearance ──────────────────────────────────────────────────────────

/// A palette layer. [dark] overrides apply only in dark mode.
class AppearanceColors {
  /// Creates an [AppearanceColors] layer. All fields optional.
  const AppearanceColors({
    this.primary,
    this.primaryForeground,
    this.background,
    this.surface,
    this.foreground,
    this.muted,
    this.border,
    this.success,
    this.error,
    this.warning,
    this.dark,
  });

  /// Primary brand color (hex, e.g. `#4F7CFF`).
  final String? primary;

  /// Foreground color used on top of [primary].
  final String? primaryForeground;

  /// Page background color.
  final String? background;

  /// Card / surface color.
  final String? surface;

  /// Default text color.
  final String? foreground;

  /// Secondary / muted text color.
  final String? muted;

  /// Border color.
  final String? border;

  /// Success state color.
  final String? success;

  /// Error / destructive state color.
  final String? error;

  /// Warning state color.
  final String? warning;

  /// Overrides applied on top of the dark base (e.g. a darker background).
  final AppearanceColors? dark;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'primary': primary,
        'primaryForeground': primaryForeground,
        'background': background,
        'surface': surface,
        'foreground': foreground,
        'muted': muted,
        'border': border,
        'success': success,
        'error': error,
        'warning': warning,
        'dark': dark?.toMap(),
      });
}

/// Font-family / custom-font overrides.
class AppearanceTypography {
  /// Creates an [AppearanceTypography] override.
  const AppearanceTypography({
    this.fontFamily,
    this.displayFamily,
    this.fontCss,
  });

  /// Body font-family stack (e.g. `'DM Sans', system-ui, sans-serif`).
  final String? fontFamily;

  /// Heading / display font-family; defaults to [fontFamily] when omitted.
  final String? displayFamily;

  /// A CSS @import / stylesheet URL or @font-face block to load custom fonts.
  final String? fontCss;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'fontFamily': fontFamily,
        'displayFamily': displayFamily,
        'fontCss': fontCss,
      });
}

/// Corner-radius and button-style overrides.
class AppearanceShape {
  /// Creates an [AppearanceShape] override.
  const AppearanceShape({
    this.radius,
    this.buttonRadius,
    this.buttonStyle,
  });

  /// Base corner radius in px (cards, inputs).
  final num? radius;

  /// Button corner radius in px; defaults to [radius].
  final num? buttonRadius;

  /// Either `'filled'` or `'outline'`.
  final String? buttonStyle;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'radius': radius,
        'buttonRadius': buttonRadius,
        'buttonStyle': buttonStyle,
      });
}

/// Logo placement override.
class AppearanceLogo {
  /// Creates an [AppearanceLogo] override.
  const AppearanceLogo({this.url, this.placement, this.height});

  /// Logo image URL.
  final String? url;

  /// Either `'header'`, `'center'`, or `'none'`.
  final String? placement;

  /// Logo height in px.
  final num? height;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'url': url,
        'placement': placement,
        'height': height,
      });
}

/// Page background override.
class AppearanceBackground {
  /// Creates an [AppearanceBackground] override.
  const AppearanceBackground({this.color, this.imageUrl});

  /// Background color (hex).
  final String? color;

  /// Background image URL.
  final String? imageUrl;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'color': color,
        'imageUrl': imageUrl,
      });
}

/// Custom illustration / icon overrides (image URLs replacing built-in glyphs).
///
/// Named slots [success], [review], and [notVerified] cover the result screens;
/// [extra] carries any other SDK-defined slot id by URL.
class AppearanceIcons {
  /// Creates an [AppearanceIcons] override.
  const AppearanceIcons({
    this.success,
    this.review,
    this.notVerified,
    this.extra,
  });

  /// Success result screen illustration URL.
  final String? success;

  /// Under-review result screen illustration URL.
  final String? review;

  /// Not-verified result screen illustration URL.
  final String? notVerified;

  /// Any other named slot keyed by id -> URL.
  final Map<String, String>? extra;

  /// camelCase wire map; null fields omitted. [extra] entries are flattened in.
  Map<String, dynamic> toMap() {
    final map = _pruned(<String, dynamic>{
      'success': success,
      'review': review,
      'notVerified': notVerified,
    });
    if (extra != null) map.addAll(extra!);
    return map;
  }
}

/// Loading-animation preset or custom asset.
class AppearanceLoader {
  /// Creates an [AppearanceLoader] override.
  const AppearanceLoader({this.style, this.imageUrl});

  /// Built-in preset: `'spinner'`, `'dots'`, or `'bar'`. Default `'spinner'`.
  final String? style;

  /// Custom loader asset URL; overrides [style].
  final String? imageUrl;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'style': style,
        'imageUrl': imageUrl,
      });
}

/// Visual white-label theming for the Flows runner. Mirrors the cross-SDK
/// `FlowAppearance` contract. All fields optional; omitted fields fall back to
/// the operator's server branding then the built-in tokens.
class FlowAppearance {
  /// Creates a [FlowAppearance].
  const FlowAppearance({
    this.colors,
    this.typography,
    this.shape,
    this.logo,
    this.background,
    this.icons,
    this.loader,
    this.mode,
  });

  /// Palette overrides.
  final AppearanceColors? colors;

  /// Typography overrides.
  final AppearanceTypography? typography;

  /// Shape / radius overrides.
  final AppearanceShape? shape;

  /// Logo placement.
  final AppearanceLogo? logo;

  /// Page background.
  final AppearanceBackground? background;

  /// Result-screen / icon-slot illustrations.
  final AppearanceIcons? icons;

  /// Loading animation.
  final AppearanceLoader? loader;

  /// Force a palette or follow the OS: `'light'`, `'dark'`, or `'auto'`.
  final String? mode;

  /// camelCase wire map the native runner decodes; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'colors': colors?.toMap(),
        'typography': typography?.toMap(),
        'shape': shape?.toMap(),
        'logo': logo?.toMap(),
        'background': background?.toMap(),
        'icons': icons?.toMap(),
        'loader': loader?.toMap(),
        'mode': mode,
      });
}

// ─── FlowCopy ────────────────────────────────────────────────────────────────

/// Optional welcome / intro shown before the first step.
class WelcomeCopy {
  /// Creates a [WelcomeCopy] override.
  const WelcomeCopy({this.title, this.body});

  /// Welcome screen title.
  final String? title;

  /// Welcome screen body.
  final String? body;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() =>
      _pruned(<String, dynamic>{'title': title, 'body': body});
}

/// Shared button labels.
class ButtonsCopy {
  /// Creates a [ButtonsCopy] override.
  const ButtonsCopy({
    this.continueLabel,
    this.cancel,
    this.tryAgain,
    this.retake,
    this.useThisPhoto,
    this.uploadInstead,
    this.scan,
    this.upload,
    this.submitting,
  });

  /// `continue` button label (named [continueLabel] since `continue` is a
  /// Dart keyword; serialized to the `continue` wire key).
  final String? continueLabel;

  /// `cancel` button label.
  final String? cancel;

  /// `tryAgain` button label.
  final String? tryAgain;

  /// `retake` button label.
  final String? retake;

  /// `useThisPhoto` button label.
  final String? useThisPhoto;

  /// `uploadInstead` button label.
  final String? uploadInstead;

  /// `scan` button label.
  final String? scan;

  /// `upload` button label.
  final String? upload;

  /// `submitting` button label.
  final String? submitting;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'continue': continueLabel,
        'cancel': cancel,
        'tryAgain': tryAgain,
        'retake': retake,
        'useThisPhoto': useThisPhoto,
        'uploadInstead': uploadInstead,
        'scan': scan,
        'upload': upload,
        'submitting': submitting,
      });
}

/// Titles shown under the loader for each transient state.
class LoadingCopy {
  /// Creates a [LoadingCopy] override.
  const LoadingCopy({
    this.defaultText,
    this.verifying,
    this.submittingDocument,
    this.checkingQuality,
  });

  /// Default loading title (serialized to the `default` wire key).
  final String? defaultText;

  /// `verifying` loading title.
  final String? verifying;

  /// `submittingDocument` loading title.
  final String? submittingDocument;

  /// `checkingQuality` loading title.
  final String? checkingQuality;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'default': defaultText,
        'verifying': verifying,
        'submittingDocument': submittingDocument,
        'checkingQuality': checkingQuality,
      });
}

/// Face capture primer copy.
class FaceCopy {
  /// Creates a [FaceCopy] override.
  const FaceCopy({this.title, this.body, this.start});

  /// Face primer title.
  final String? title;

  /// Face primer body.
  final String? body;

  /// Start button label.
  final String? start;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'title': title,
        'body': body,
        'start': start,
      });
}

/// Document capture surface copy.
class DocumentCopy {
  /// Creates a [DocumentCopy] override.
  const DocumentCopy({
    this.selectTitle,
    this.selectBody,
    this.primerTitle,
    this.primerBody,
    this.uploadTitle,
    this.uploadBody,
    this.scanTitle,
    this.scanBody,
    this.confirmTitle,
    this.confirmBody,
  });

  /// Document-type selection title.
  final String? selectTitle;

  /// Document-type selection body.
  final String? selectBody;

  /// Capture primer title.
  final String? primerTitle;

  /// Capture primer body.
  final String? primerBody;

  /// Upload surface title.
  final String? uploadTitle;

  /// Upload surface body.
  final String? uploadBody;

  /// Scan surface title.
  final String? scanTitle;

  /// Scan surface body.
  final String? scanBody;

  /// Confirm surface title.
  final String? confirmTitle;

  /// Confirm surface body.
  final String? confirmBody;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'selectTitle': selectTitle,
        'selectBody': selectBody,
        'primerTitle': primerTitle,
        'primerBody': primerBody,
        'uploadTitle': uploadTitle,
        'uploadBody': uploadBody,
        'scanTitle': scanTitle,
        'scanBody': scanBody,
        'confirmTitle': confirmTitle,
        'confirmBody': confirmBody,
      });
}

/// Form surface copy.
class FormCopy {
  /// Creates a [FormCopy] override.
  const FormCopy({this.title});

  /// Form title.
  final String? title;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{'title': title});
}

/// ID-number surface copy.
class IdNumberCopy {
  /// Creates an [IdNumberCopy] override.
  const IdNumberCopy({this.title, this.body});

  /// ID-number entry title.
  final String? title;

  /// ID-number entry body.
  final String? body;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() =>
      _pruned(<String, dynamic>{'title': title, 'body': body});
}

/// Terminal result-screen copy.
class ResultCopy {
  /// Creates a [ResultCopy] override.
  const ResultCopy({
    this.successTitle,
    this.successBody,
    this.reviewTitle,
    this.reviewBody,
    this.notVerifiedTitle,
    this.notVerifiedBody,
    this.cancelledTitle,
  });

  /// Success screen title.
  final String? successTitle;

  /// Success screen body.
  final String? successBody;

  /// Under-review screen title.
  final String? reviewTitle;

  /// Under-review screen body.
  final String? reviewBody;

  /// Not-verified screen title.
  final String? notVerifiedTitle;

  /// Not-verified screen body.
  final String? notVerifiedBody;

  /// Cancelled screen title.
  final String? cancelledTitle;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'successTitle': successTitle,
        'successBody': successBody,
        'reviewTitle': reviewTitle,
        'reviewBody': reviewBody,
        'notVerifiedTitle': notVerifiedTitle,
        'notVerifiedBody': notVerifiedBody,
        'cancelledTitle': cancelledTitle,
      });
}

/// Error copy (provider failure vs unreadable capture vs generic).
class ErrorsCopy {
  /// Creates an [ErrorsCopy] override.
  const ErrorsCopy({
    this.generic,
    this.providerUnavailable,
    this.documentUnreadable,
  });

  /// Generic error message.
  final String? generic;

  /// Provider-unavailable error message.
  final String? providerUnavailable;

  /// Unreadable-document error message.
  final String? documentUnreadable;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'generic': generic,
        'providerUnavailable': providerUnavailable,
        'documentUnreadable': documentUnreadable,
      });
}

/// Privacy / consent disclosures shown to the subject.
class PrivacyCopy {
  /// Creates a [PrivacyCopy] override.
  const PrivacyCopy({this.disclosure, this.consentTitle, this.consentBody});

  /// Privacy disclosure text.
  final String? disclosure;

  /// Consent screen title.
  final String? consentTitle;

  /// Consent screen body.
  final String? consentBody;

  /// camelCase wire map; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'disclosure': disclosure,
        'consentTitle': consentTitle,
        'consentBody': consentBody,
      });
}

/// Subject-facing string overrides for the Flows runner. Mirrors the cross-SDK
/// `FlowCopy` contract. All fields optional; omitted keys keep the built-in
/// (or server-configured) copy.
class FlowCopy {
  /// Creates a [FlowCopy].
  const FlowCopy({
    this.welcome,
    this.buttons,
    this.loading,
    this.face,
    this.document,
    this.form,
    this.idNumber,
    this.result,
    this.errors,
    this.privacy,
    this.help,
  });

  /// Welcome / intro copy.
  final WelcomeCopy? welcome;

  /// Shared button labels.
  final ButtonsCopy? buttons;

  /// Loader titles.
  final LoadingCopy? loading;

  /// Face capture primer.
  final FaceCopy? face;

  /// Document capture surfaces.
  final DocumentCopy? document;

  /// Form surface.
  final FormCopy? form;

  /// ID-number surface.
  final IdNumberCopy? idNumber;

  /// Terminal result screens.
  final ResultCopy? result;

  /// Error copy.
  final ErrorsCopy? errors;

  /// Privacy / consent copy.
  final PrivacyCopy? privacy;

  /// Free-form help text / tooltips keyed by an SDK-defined slot id.
  final Map<String, String>? help;

  /// camelCase wire map the native runner decodes; null fields omitted.
  Map<String, dynamic> toMap() => _pruned(<String, dynamic>{
        'welcome': welcome?.toMap(),
        'buttons': buttons?.toMap(),
        'loading': loading?.toMap(),
        'face': face?.toMap(),
        'document': document?.toMap(),
        'form': form?.toMap(),
        'idNumber': idNumber?.toMap(),
        'result': result?.toMap(),
        'errors': errors?.toMap(),
        'privacy': privacy?.toMap(),
        'help': help,
      });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Drop null entries so an unset override never reaches (and blanks) the native
/// default. Empty nested maps are dropped too.
Map<String, dynamic> _pruned(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  input.forEach((key, value) {
    if (value == null) return;
    if (value is Map && value.isEmpty) return;
    out[key] = value;
  });
  return out;
}
