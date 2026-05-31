class Experience {
  const Experience({
    required this.company,
    required this.role,
    required this.period,
    required this.description,
    required this.tags,
    this.isFreelance = false,
  });

  final String company;
  final String role;
  final String period;
  final String description;
  final List<String> tags;
  final bool isFreelance;
}
