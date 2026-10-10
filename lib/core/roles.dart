class RoleDef {
  final String en, ur;
  const RoleDef(this.en, this.ur);
}

const builtInRoles = <RoleDef>[
  RoleDef('Plaintiff', 'مدعی'),
  RoleDef('Defendant', 'مدعا علیہ'),
  RoleDef('Applicant', 'درخواست گزار'),
  RoleDef('Respondent', 'مستجیب (جواب دہندہ)'),
  RoleDef('Petitioner', 'درخواست گزار (پٹیشنر)'),
  RoleDef('Appellant', 'اپیل کنندہ'),
  RoleDef('Complainant', 'مستغیث'),
  RoleDef('Accused', 'ملزم'),
  RoleDef('State (Prosecution)', 'ریاست (استغاثہ)'),
  RoleDef('Revision Petitioner', 'نظرثانی کنندہ'),
  RoleDef('Decree Holder', 'ڈگری ہولڈر'),
  RoleDef('Judgment Debtor', 'مدیونِ ڈگری'),
  RoleDef('Opposite Party', 'مخالف فریق'),
  RoleDef('Objector', 'معترض'),
];

class CategoryDef {
  final String en, ur, roleA, roleB;
  const CategoryDef(this.en, this.ur, this.roleA, this.roleB);
}

/// Category -> default role pair (user can always change the roles).
const builtInCategories = <CategoryDef>[
  CategoryDef('Civil Suit', 'دیوانی دعویٰ', 'Plaintiff', 'Defendant'),
  CategoryDef('Criminal Case', 'فوجداری مقدمہ', 'Complainant', 'Accused'),
  CategoryDef('Bail Application', 'درخواستِ ضمانت', 'Applicant', 'State (Prosecution)'),
  CategoryDef('Application/Misc.', 'متفرق درخواست', 'Applicant', 'Respondent'),
  CategoryDef('Appeal', 'اپیل', 'Appellant', 'Respondent'),
  CategoryDef('Revision', 'نظرثانی', 'Revision Petitioner', 'Respondent'),
  CategoryDef('Writ Petition', 'رٹ پٹیشن', 'Petitioner', 'Respondent'),
  CategoryDef('Execution', 'اجرائے ڈگری', 'Decree Holder', 'Judgment Debtor'),
  CategoryDef('Family', 'فیملی', 'Plaintiff', 'Defendant'),
  CategoryDef('Rent', 'کرایہ داری', 'Applicant', 'Respondent'),
  CategoryDef('Banking', 'بینکاری', 'Plaintiff', 'Defendant'),
  CategoryDef('Service', 'سروس', 'Petitioner', 'Respondent'),
  CategoryDef('Tax', 'ٹیکس', 'Appellant', 'Respondent'),
  CategoryDef('Consumer', 'صارف', 'Complainant', 'Opposite Party'),
  CategoryDef('Arbitration', 'ثالثی', 'Applicant', 'Respondent'),
  CategoryDef('Other', 'دیگر', 'Applicant', 'Respondent'),
];

/// Display label for a stored (English) role in the given language.
/// [custom] maps English label -> Urdu label for user-defined roles.
String roleLabel(String role, String lang, [Map<String, String> custom = const {}]) {
  if (role.isEmpty) return '';
  if (lang != 'ur') return role;
  for (final r in builtInRoles) {
    if (r.en == role) return r.ur;
  }
  final u = custom[role];
  return (u != null && u.isNotEmpty) ? u : role;
}

String categoryLabel(String cat, String lang, [Map<String, String> custom = const {}]) {
  if (cat.isEmpty || lang != 'ur') return cat;
  for (final c in builtInCategories) {
    if (c.en == cat) return c.ur;
  }
  final u = custom[cat];
  return (u != null && u.isNotEmpty) ? u : cat;
}
